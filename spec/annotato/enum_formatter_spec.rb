# frozen_string_literal: true

require "spec_helper"
require "annotato/enum_formatter"

RSpec.describe Annotato::EnumFormatter do
  let(:connection) { double("Connection", adapter_name: "PostgreSQL") }

  describe ".pg_enums" do
    it "groups labels by type name with a single query" do
      expect(connection).to receive(:exec_query).once
        .with(/format_type\(t\.oid, NULL\).*ORDER BY t\.oid, e\.enumsortorder/, "SQL")
        .and_return([
          { "type_name" => "user_role", "label" => "admin" },
          { "type_name" => "user_role", "label" => "viewer" },
          { "type_name" => "billing.status", "label" => "paid" }
        ])

      expect(described_class.pg_enums(connection)).to eq(
        "user_role" => %w[admin viewer],
        "billing.status" => %w[paid]
      )
    end

    it "returns an empty hash without querying on other adapters" do
      %w[Mysql2 Trilogy SQLite].each do |adapter|
        conn = double("Connection", adapter_name: adapter)
        expect(conn).not_to receive(:exec_query)
        expect(described_class.pg_enums(conn)).to eq({})
      end
    end
  end

  describe ".format" do
    let(:pg_enums) { { "access_link_category" => %w[internal external partner], "user_role" => %w[admin viewer] } }

    it "returns empty array when no column uses a native PG enum" do
      columns = [double("Column", name: "id", sql_type: "bigint"), double("Column", name: "status", sql_type: "integer")]

      expect(described_class.format(connection, columns, pg_enums: pg_enums)).to eq([])
    end

    it "returns a flat array of comment lines" do
      columns = [double("Column", name: "id", sql_type: "bigint"),
                 double("Column", name: "category", sql_type: "access_link_category")]

      expect(described_class.format(connection, columns, pg_enums: pg_enums)).to eq([
        "#  category (access_link_category): [",
        "#    internal,",
        "#    external,",
        "#    partner",
        "#  ]"
      ])
    end

    it "strips the array suffix for enum array columns" do
      columns = [double("Column", name: "roles", sql_type: "user_role[]")]

      expect(described_class.format(connection, columns, pg_enums: pg_enums)).to eq([
        "#  roles (user_role[]): [", "#    admin,", "#    viewer", "#  ]"
      ])
    end

    it "fetches enums from the connection when none are given" do
      allow(connection).to receive(:exec_query).and_return([{ "type_name" => "user_role", "label" => "admin" }])
      columns = [double("Column", name: "role", sql_type: "user_role")]

      expect(described_class.format(connection, columns)).to include("#    admin")
    end
  end
end
