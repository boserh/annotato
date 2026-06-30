# frozen_string_literal: true

require "spec_helper"
require "annotato/enum_formatter"

RSpec.describe Annotato::EnumFormatter do
  let(:connection) { double("Connection") }

  def pg_type_result(exists)
    exists ? [{ "typname" => "my_enum" }] : []
  end

  context "when no columns have a native PG enum type" do
    let(:columns) do
      [
        double("Column", name: "id", sql_type: "bigint"),
        double("Column", name: "status", sql_type: "integer")
      ]
    end

    before do
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, anything)
        .and_return([])
    end

    it "returns empty array" do
      expect(described_class.format(connection, columns)).to eq([])
    end
  end

  context "when a column has a native PG enum type" do
    let(:columns) do
      [
        double("Column", name: "id", sql_type: "bigint"),
        double("Column", name: "category", sql_type: "access_link_category")
      ]
    end

    before do
      # bigint is not an enum
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["bigint"])
        .and_return([])

      # access_link_category is a native enum
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["access_link_category"])
        .and_return([{ "typname" => "access_link_category" }])

      # labels query
      allow(connection).to receive(:exec_query)
        .with(/SELECT e.enumlabel/, anything, ["access_link_category"])
        .and_return([
          { "enumlabel" => "internal" },
          { "enumlabel" => "external" },
          { "enumlabel" => "partner" }
        ])
    end

    it "formats the DB enum type definition" do
      result = described_class.format(connection, columns)
      expect(result.size).to eq(1)
      expect(result.first).to eq(<<~ENUM.strip)
        #  category (access_link_category): [
        #    internal,
        #    external,
        #    partner
        #  ]
      ENUM
    end
  end

  context "when a column uses an array of a native PG enum type (e.g. my_enum[])" do
    let(:columns) do
      [double("Column", name: "roles", sql_type: "user_role[]")]
    end

    before do
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["user_role"])
        .and_return([{ "typname" => "user_role" }])

      allow(connection).to receive(:exec_query)
        .with(/SELECT e.enumlabel/, anything, ["user_role"])
        .and_return([
          { "enumlabel" => "admin" },
          { "enumlabel" => "viewer" }
        ])
    end

    it "strips the array suffix and formats the enum type" do
      result = described_class.format(connection, columns)
      expect(result.size).to eq(1)
      expect(result.first).to include("roles (user_role[]): [")
      expect(result.first).to include("#    admin,")
      expect(result.first).to include("#    viewer")
    end
  end
end
