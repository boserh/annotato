# frozen_string_literal: true

require "spec_helper"
require "annotato/model_annotator"
require "pathname"

# Minimal Rails mock
module Rails
  def self.application
    Class.new {
      def eager_load!; true; end
    }.new
  end

  def self.root
    Pathname.new(Dir.pwd)
  end
end

class User
  def self.table_exists?; true; end
  def self.name; "User"; end
  def self.abstract_class?; false; end
  def self.primary_key; "id"; end
  def self.base_class; self; end
end

RSpec.describe Annotato::ModelAnnotator do
  let(:annotator) { described_class.new(output: output) }
  let(:output) { StringIO.new }
  let(:file_path) { File.join(Dir.pwd, "app/models/user.rb") }
  let(:file_content) { "class User\nend\n" }
  let(:annotation) { "# == Annotato Schema Info\n# Table: users\n# Columns:\n#  id :bigint not null, primary key" }

  before do
    allow(Rails.application).to receive(:eager_load!).and_return(true)
    allow(ActiveRecord::Base).to receive(:descendants).and_return([User])

    allow(Object).to receive(:const_source_location).with("User").and_return([file_path, 1])

    allow(File).to receive(:exist?).with(file_path).and_return(true)
    allow(File).to receive(:read).with(file_path).and_return(file_content)
    allow(annotator).to receive(:write_file)

    allow(Annotato::AnnotationBuilder).to receive(:build).with(User).and_return(annotation)
  end

  describe "#run" do
    it "annotates models and writes annotation" do
      expect(annotator).to receive(:write_file).with(file_path, including(annotation))
      annotator.run
      expect(output.string).to include("✍️  Annotated User")
    end

    it "skips models without table" do
      allow(User).to receive(:table_exists?).and_return(false)
      expect(annotator).not_to receive(:write_file)
      annotator.run
    end
  end
end
