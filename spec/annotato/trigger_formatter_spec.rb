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

  context "PostGIS adapter" do
    include_examples "formats trigger names",
      "PostGIS",
      "SELECT tgname AS name FROM pg_trigger WHERE tgrelid = $1::regclass AND NOT tgisinternal",
      ["users"]
  end

  context "SQLite adapter (ADAPTER_NAME is \"SQLite\")" do
    include_examples "formats trigger names",
      "SQLite",
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ?",
      ["users"]
  end

  %w[Mysql2 Trilogy].each do |adapter|
    context "#{adapter} adapter" do
      before do
        allow(connection).to receive(:adapter_name).and_return(adapter)
        allow(connection).to receive(:quote).with("users").and_return("'users'")
      end

      it "quotes the table name instead of binding it" do
        expect(connection).to receive(:exec_query)
          .with(/EVENT_OBJECT_TABLE = 'users'\z/, "SQL")
          .and_return([{ "name" => "b_trigger" }, { "name" => "a_trigger" }])

        expect(described_class.format(connection, "users")).to eq(["#  a_trigger", "#  b_trigger"])
      end
    end
  end

  context "unsupported adapter" do
    before { allow(connection).to receive(:adapter_name).and_return("OracleEnhanced") }

    it "returns empty array without querying" do
      expect(connection).not_to receive(:exec_query)
      expect(described_class.format(connection, "users")).to eq([])
    end
  end
end
