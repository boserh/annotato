# frozen_string_literal: true

require "spec_helper"
require "annotato/enum_formatter"

RSpec.describe Annotato::EnumFormatter do
  let(:connection) { double("Connection") }

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
      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["bigint"])
        .and_return([])

      allow(connection).to receive(:exec_query)
        .with(/SELECT 1 FROM pg_type/, anything, ["access_link_category"])
        .and_return([{ "typname" => "access_link_category" }])

      allow(connection).to receive(:exec_query)
        .with(/SELECT e.enumlabel/, anything, ["access_link_category"])
        .and_return([
          { "enumlabel" => "internal" },
          { "enumlabel" => "external" },
          { "enumlabel" => "partner" }
        ])
    end

    it "returns a flat array of comment lines" do
      result = described_class.format(connection, columns)
      expect(result).to eq([
        "#  category (access_link_category): [",
        "#    internal,",
        "#    external,",
        "#    partner",
        "#  ]"
      ])
    end

    it "includes all labels including the last one" do
      result = described_class.format(connection, columns)
      expect(result).to include("#    partner")
      expect(result.last).to eq("#  ]")
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
      expect(result).to include("#  roles (user_role[]): [")
      expect(result).to include("#    admin,")
      expect(result).to include("#    viewer")
      expect(result).to include("#  ]")
    end
  end
end
