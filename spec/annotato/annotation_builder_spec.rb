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
      columns = [
        double(name: "id", sql_type: "bigint", default: nil, null: false),
        double(name: "category", sql_type: "access_link_category", default: nil, null: false)
      ]

      allow(connection).to receive(:columns).with(table_name).and_return(columns)
      allow(model).to receive(:primary_key).and_return("id")

      allow(connection).to receive(:indexes).with(table_name).and_return([
        double(name: "index_users_on_email", columns: ["email"], unique: true, where: nil)
      ])

      # Triggers query
      allow(connection).to receive(:exec_query)
        .with(/pg_trigger/, anything, anything)
        .and_return([{ "tgname" => "audit_trigger_row" }])

      # ColumnFormatter: pg_enum_type_names (fetches all PG enum types at once)
      allow(connection).to receive(:exec_query)
        .with(/SELECT typname FROM pg_type/, "SQL")
        .and_return([{ "typname" => "access_link_category" }])

      # EnumFormatter: pg_enum_type? checks per column
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["bigint"])
        .and_return([])
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["access_link_category"])
        .and_return([{ "typname" => "access_link_category" }])

      # EnumFormatter: labels for access_link_category
      allow(connection).to receive(:exec_query)
        .with(/SELECT e.enumlabel/, anything, ["access_link_category"])
        .and_return([{ "enumlabel" => "internal" }, { "enumlabel" => "external" }])

      allow(connection).to receive(:check_constraints).with(table_name).and_return([
        double(table_name: table_name, name: "chk_positive_age", expression: "age > 0")
      ])

      annotation = described_class.build(model)

      expect(annotation).to include("== Annotato Schema Info")
      expect(annotation).to include("Columns:")
      expect(annotation).to include("Indexes:")
      expect(annotation).to include("Triggers:")
      expect(annotation).to include("Enums:")
      expect(annotation).to include("Check Constraints:")
      expect(annotation).to include("category (access_link_category): [")
      expect(annotation).to include("internal")
      expect(annotation).to include("external")
    end

    it "does not include Enums, Indexes, Triggers, or Check Constraints sections if none exist" do
      allow(connection).to receive(:columns).with(table_name).and_return([])
      allow(connection).to receive(:indexes).with(table_name).and_return([])
      allow(model).to receive(:primary_key).and_return("id")
      allow(connection).to receive(:check_constraints).with(table_name).and_return([])

      # No triggers
      allow(connection).to receive(:exec_query)
        .with(/pg_trigger/, anything, anything)
        .and_return([])

      # No native PG enum types in the DB
      allow(connection).to receive(:exec_query)
        .with(/SELECT typname FROM pg_type/, "SQL")
        .and_return([])

      annotation = described_class.build(model)

      expect(annotation).to include("Columns:")
      expect(annotation).not_to include("Indexes:")
      expect(annotation).not_to include("Triggers:")
      expect(annotation).not_to include("Enums:")
      expect(annotation).not_to include("Check Constraints:")    end
  end
end
