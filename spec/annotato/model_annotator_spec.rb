# frozen_string_literal: true

require "stringio"
require_relative "../../lib/annotato/model_annotator"
require_relative "../../lib/annotato/annotation_builder"

require "singleton"

# Minimal mock of Rails.application for tests
module Rails
  def self.application
    Application.instance
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
  let(:model) { double("Model", name: "User", table_exists?: true, abstract_class?: false) }
  let(:annotation) { "# == Annotato Schema Info\n# Table: users\n# Columns:\n#  id :bigint not null, primary key\n" }

  before do
    allow(Annotato::AnnotationBuilder).to receive(:build).with(model).and_return(annotation)
  end

  describe "#write_annotation" do
    it "skips writing annotation and outputs info message when annotation unchanged" do
      file = "spec/annotato/tmp_user.rb"
      File.write(file, annotation + "\nclass User\nend\n")
      allow(annotator).to receive(:model_file).and_return(file)

      annotator.send(:write_annotation, model, annotation)
      expect(output.string).to include("ℹ️  Skipped User — annotation unchanged")

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

    context "when source_location is nil" do
      before do
        allow(model).to receive_message_chain(:instance_method, :source_location).and_return(nil)
        allow(Object).to receive(:const_source_location).with(model.name).and_return(["/app/models/fallback.rb", 123])
      end

      it "falls back to const_source_location" do
        result = annotator.send(:model_file, model)
        expect(result).to eq("/app/models/fallback.rb")
      end
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
