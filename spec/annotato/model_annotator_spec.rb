# frozen_string_literal: true

require "stringio"
require_relative "../../lib/annotato/model_annotator"
require_relative "../../lib/annotato/annotation_builder"

require "singleton"
require "pathname"
require "tmpdir"

# Minimal mock of Rails.application for tests
module Rails
  def self.application
    Application.instance
  end

  def self.root
    Pathname.new(Dir.pwd)
  end

  class Application
    include Singleton

    def eager_load!
      true
    end
  end
end

RSpec.describe Annotato::ModelAnnotator do
  let(:output) { StringIO.new }
  let(:annotator) { described_class.new(output: output) }
  let(:model) do
    # base class should be the same as the model itself
    # in a real application, this would be ActiveRecord::Base or a subclass
    # here we just mock it for the sake of the test
    instance = double("Model", name: "User", table_exists?: true, abstract_class?: false)
    allow(instance).to receive(:base_class).and_return(instance)
    instance
  end
  let(:annotation) { "# == Annotato Schema Info\n# Table: users\n# Columns:\n#  id :bigint not null, primary key\n" }

  before do
    allow(Annotato::AnnotationBuilder).to receive(:build).with(model).and_return(annotation)
  end

  describe "#write_annotation" do
    it "skips writing annotation silently when annotation unchanged" do
      file = "spec/annotato/tmp_user.rb"
      File.write(file, annotation + "\nclass User\nend\n")
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      expect(output.string).to eq("")

      File.delete(file)
    end

    it "skips writing and outputs warning when class definition is missing" do
      file = "spec/annotato/tmp_user2.rb"
      File.write(file, "module Foo; end")
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      expect(output.string).to include("⚠️  Skipped User — class not found in file")

      File.delete(file)
    end

    it "writes new annotation to file" do
      file = "spec/annotato/tmp_user3.rb"
      content = "class User\nend\n"
      File.write(file, content)
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      new_content = File.read(file)
      expect(new_content).to include(annotation.strip)
      expect(output.string).to include("✍️  Annotated User")

      File.delete(file)
    end

    it "removes a legacy block above a module-wrapped class without touching the code" do
      file = "spec/annotato/tmp_user4.rb"
      code = "module Admin\n  class User < ApplicationRecord\n    def name; end\n  end\nend\n"
      File.write(file, "# frozen_string_literal: true\n\n# == Schema Information\n#\n# Table name: users\n#\n\n#{code}")
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      new_content = File.read(file)
      expect(new_content).to start_with("# frozen_string_literal: true\n")
      expect(new_content).to include(code)
      expect(new_content).not_to include("== Schema Information")
      expect(new_content).to end_with("#{annotation.strip}\n")
    ensure
      File.delete(file)
    end

    it "replaces an annotato block above a module without touching the code" do
      file = "spec/annotato/tmp_user5.rb"
      code = "module Admin\n  class User\n  end\nend\n"
      File.write(file, "# == Annotato Schema Info\n# Table: old_users\n#\n#{code}")
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      new_content = File.read(file)
      expect(new_content).to include(code)
      expect(new_content).not_to include("old_users")
      expect(new_content.scan("== Annotato Schema Info").size).to eq(1)
    ensure
      File.delete(file)
    end

    it "removes a legacy block even when the annotato block is unchanged" do
      file = "spec/annotato/tmp_user6.rb"
      File.write(file, "# == Schema Information\n# Table name: users\n\nclass User\nend\n\n#{annotation}")
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      expect(File.read(file)).to eq("class User\nend\n\n#{annotation.strip}\n")
    ensure
      File.delete(file)
    end
  end

  describe "#model_file" do
    it "returns the source file when it is inside the application" do
      path = File.join(Dir.pwd, "app/models/user.rb")
      allow(Object).to receive(:const_source_location).with("User").and_return([path, 1])

      expect(annotator.send(:model_file, model)).to eq(path)
    end

    it "ignores files outside the application (gems, engines)" do
      path = File.join(Dir.tmpdir, "gems/activestorage/app/models/active_storage/blob.rb")
      allow(Object).to receive(:const_source_location).with("User").and_return([path, 1])

      expect(annotator.send(:model_file, model)).to be_nil
    end

    it "ignores files under vendor/" do
      path = File.join(Dir.pwd, "vendor/bundle/gems/foo/app/models/user.rb")
      allow(Object).to receive(:const_source_location).with("User").and_return([path, 1])

      expect(annotator.send(:model_file, model)).to be_nil
    end

    it "returns nil for anonymous classes" do
      anonymous = double("Model", name: nil)

      expect(annotator.send(:model_file, anonymous)).to be_nil
    end
  end

  describe "#run" do
    it "annotates models and writes annotation" do
      allow(Rails.application).to receive(:eager_load!).and_return(true)
      allow(ActiveRecord::Base).to receive(:descendants).and_return([model])
      allow(model).to receive(:abstract_class?).and_return(false)
      allow(model).to receive(:table_exists?).and_return(true)
      allow(annotator).to receive(:write_annotation).with(model, annotation)

      annotator.run

      expect(Annotato::AnnotationBuilder).to have_received(:build).with(model)
      expect(annotator).to have_received(:write_annotation).with(model, annotation)
    end

    it "skips anonymous classes and HABTM join models" do
      anonymous = double("Anonymous", name: nil, abstract_class?: false)
      allow(anonymous).to receive(:base_class).and_return(anonymous)
      habtm = double("HABTM", name: "User::HABTM_Roles", abstract_class?: false)
      allow(habtm).to receive(:base_class).and_return(habtm)
      allow(ActiveRecord::Base).to receive(:descendants).and_return([anonymous, habtm, model])

      expect(annotator.send(:models)).to eq([model])
    end

    it "skips models without table" do
      allow(Rails.application).to receive(:eager_load!).and_return(true)
      allow(ActiveRecord::Base).to receive(:descendants).and_return([model])
      allow(model).to receive(:abstract_class?).and_return(false)
      allow(model).to receive(:table_exists?).and_return(false)
      expect(annotator).not_to receive(:write_annotation)

      annotator.run
    end
  end
end
