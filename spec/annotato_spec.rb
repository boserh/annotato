# frozen_string_literal: true

require "spec_helper"
require "annotato/model_annotator"

# Minimal Rails mock
module Rails
  def self.application
    Class.new {
      def eager_load!; true; end
    }.new
  end
end

module ActiveRecord
  class Base
    def self.descendants; [User]; end

    def self.connection
      @connection_double
    end

    def self.connection=(conn)
      @connection_double = conn
    end
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
  let(:connection_double) { double("Connection") }
  let(:mock_method) { double(source_location: [file_path, 1]) }
  let(:file_path) { "/tmp/user.rb" }
  let(:file_content) { "class User\nend\n" }
  let(:annotation) { "# == Annotato Schema Info\n# Table: users\n# Columns:\n#  id :bigint not null, primary key" }

  before do
    ActiveRecord::Base.connection = connection_double

    allow(Rails.application).to receive(:eager_load!).and_return(true)
    allow(ActiveRecord::Base).to receive(:descendants).and_return([User])

    allow(User).to receive(:instance_method).with(:initialize).and_return(mock_method)
    allow(Object).to receive(:const_source_location).with("User").and_return([file_path, 1])

    allow(File).to receive(:exist?).with(file_path).and_return(true)
    allow(File).to receive(:read).with(file_path).and_return(file_content)
    allow(File).to receive(:write).with(file_path, any_args)

    allow(connection_double).to receive(:indexes).and_return([])
    allow(connection_double).to receive(:exec_query).and_return([])
    allow(connection_double).to receive(:columns).and_return([])

    allow(Annotato::AnnotationBuilder).to receive(:build).with(User).and_return(annotation)
  end

  describe "#run" do
    it "annotates models and writes annotation" do
      expect(File).to receive(:write).with(file_path, including(annotation))
      annotator.run
      expect(output.string).to include("✍️  Annotated User")
      expect(output.string).to include("✅ Annotato completed")
    end

    it "skips models without table" do
      allow(User).to receive(:table_exists?).and_return(false)
      expect(File).not_to receive(:write)
      annotator.run
      expect(output.string).to include("✅ Annotato completed")
    end
  end
end
