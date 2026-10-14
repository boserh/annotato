# frozen_string_literal: true

require "spec_helper"
require "annotato/annotation_builder"

RSpec.describe Annotato::AnnotationBuilder do
  let(:model) { double("Model") }
  let(:connection) { double("Connection") }
  let(:table_name) { "users" }

  before do
    allow(model).to receive(:table_name).and_return(table_name)
    allow(model).to receive(:connection).and_return(connection)
    allow(connection).to receive(:adapter_name).and_return("PostgreSQL")
    allow(connection).to receive(:supports_check_constraints?).and_return(true)
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

      allow(connection).to receive(:exec_query)
        .with(/pg_trigger/, anything, anything)
        .and_return([{ "name" => "audit_trigger_row" }])

      # All native PG enums with their labels, fetched once
      allow(connection).to receive(:exec_query)
        .with(/FROM pg_type t JOIN pg_enum/, "SQL")
        .and_return([
          { "type_name" => "access_link_category", "label" => "internal" },
          { "type_name" => "access_link_category", "label" => "external" }
        ])

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
      expect(annotation).to match(/category\s+:access_link_category not null, enum/)
    end

    it "does not include Enums, Indexes, Triggers, or Check Constraints sections if none exist" do
      allow(connection).to receive(:columns).with(table_name).and_return([])
      allow(connection).to receive(:indexes).with(table_name).and_return([])
      allow(model).to receive(:primary_key).and_return("id")
      allow(connection).to receive(:check_constraints).with(table_name).and_return([])
      allow(connection).to receive(:exec_query).with(/pg_trigger/, anything, anything).and_return([])
      allow(connection).to receive(:exec_query).with(/pg_enum/, "SQL").and_return([])

      annotation = described_class.build(model)

      expect(annotation).to include("Columns:")
      expect(annotation).not_to include("Indexes:")
      expect(annotation).not_to include("Triggers:")
      expect(annotation).not_to include("Enums:")
      expect(annotation).not_to include("Check Constraints:")
    end

    context "with a minimal schema" do
      before do
        allow(connection).to receive(:columns).with(table_name).and_return([])
        allow(connection).to receive(:indexes).with(table_name).and_return([])
        allow(model).to receive(:primary_key).and_return("id")
        allow(connection).to receive(:check_constraints).with(table_name).and_return([])
        allow(connection).to receive(:exec_query).and_return([])
      end

      it "uses with_connection when the model supports it" do
        allow(model).to receive(:with_connection).and_yield(connection)

        described_class.build(model)

        expect(model).to have_received(:with_connection)
        expect(model).not_to have_received(:connection)
      end

      it "includes the table comment when present" do
        allow(connection).to receive(:table_comment).with(table_name).and_return("People who log in")

        expect(described_class.build(model)).to include("# Table: users\n# Comment: People who log in\n")
      end
    end
  end
end
