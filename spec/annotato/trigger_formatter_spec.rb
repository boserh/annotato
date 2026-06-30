# frozen_string_literal: true

require "spec_helper"
require "annotato/trigger_formatter"

RSpec.describe Annotato::TriggerFormatter do
  let(:connection) { double("Connection") }

  shared_examples "formats trigger names" do |adapter, sql_pattern, bind_params|
    before { allow(connection).to receive(:adapter_name).and_return(adapter) }

    it "queries with correct SQL and formats results" do
      allow(connection).to receive(:exec_query)
        .with(sql_pattern, "SQL", bind_params)
        .and_return([{ "name" => "audit_trigger" }, { "name" => "update_timestamp" }])

      result = described_class.format(connection, "users")
      expect(result).to eq(["#  audit_trigger", "#  update_timestamp"])
    end

    it "uses a parameterized query (no string interpolation)" do
      expect(connection).to receive(:exec_query)
        .with(sql_pattern, "SQL", bind_params)
        .and_return([])

      described_class.format(connection, "users")
    end
  end

  context "PostgreSQL adapter" do
    include_examples "formats trigger names",
      "PostgreSQL",
      "SELECT tgname AS name FROM pg_trigger WHERE tgrelid = $1::regclass AND NOT tgisinternal",
      ["users"]
  end

  context "MySQL2 adapter" do
    include_examples "formats trigger names",
      "Mysql2",
      /EVENT_OBJECT_TABLE/,
      ["users"]
  end

  context "SQLite3 adapter" do
    include_examples "formats trigger names",
      "SQLite3",
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ?",
      ["users"]
  end

  context "unsupported adapter" do
    before { allow(connection).to receive(:adapter_name).and_return("OracleEnhanced") }

    it "returns empty array without querying" do
      expect(connection).not_to receive(:exec_query)
      expect(described_class.format(connection, "users")).to eq([])
    end
  end
end
