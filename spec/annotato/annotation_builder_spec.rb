# frozen_string_literal: true

require "spec_helper"
require "annotato/annotation_builder"

# Minimal ActiveRecord mock to avoid NameError
module ActiveRecord
  class Base
    class << self
      attr_accessor :connection
    end
  end
end

RSpec.describe Annotato::AnnotationBuilder do
  let(:model) { double("Model") }
  let(:connection) { double("Connection") }
  let(:table_name) { "users" }

  before do
    allow(model).to receive(:table_name).and_return(table_name)
    ActiveRecord::Base.connection = connection
  end

  describe ".build" do
    it "builds full annotation with all sections" do
      allow(connection).to receive(:columns).with(table_name).and_return([
        double(name: "id", sql_type: "bigint", default: nil, null: false),
        double(name: "status", sql_type: "integer", default: "draft", null: false)
      ])

      allow(model).to receive(:defined_enums).and_return({
        "status" => { "draft" => "0", "published" => "1" }
      })

      allow(model).to receive(:primary_key).and_return("id")

      allow(connection).to receive(:indexes).with(table_name).and_return([
        double(name: "index_users_on_email", columns: ["email"], unique: true)
      ])

      allow(connection).to receive(:exec_query).and_return([
        { "tgname" => "audit_trigger_row" }
      ])

      annotation = described_class.build(model)

      expect(annotation).to include("== Annotato Schema Info")
      expect(annotation).to include("Columns:")
      expect(annotation).to include("Indexes:")
      expect(annotation).to include("Triggers:")
      expect(annotation).to include("Enums:")
      expect(annotation).to include(<<~ENUM.strip)
        #  status: {
        #    draft (0),
        #    published (1)
        #  }
      ENUM
    end

    it "does not include indexes or triggers if none exist" do
      allow(connection).to receive(:columns).with(table_name).and_return([])
      allow(model).to receive(:defined_enums).and_return({})
      allow(connection).to receive(:indexes).with(table_name).and_return([])
      allow(connection).to receive(:exec_query).and_return([])
      allow(model).to receive(:primary_key).and_return("id")

      annotation = described_class.build(model)

      expect(annotation).to include("Columns:")
      expect(annotation).not_to include("Indexes:")
      expect(annotation).not_to include("Triggers:")
      expect(annotation).not_to include("Enums:")
    end
  end
end
