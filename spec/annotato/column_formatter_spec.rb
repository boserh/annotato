# frozen_string_literal: true

require "spec_helper"
require "annotato/column_formatter"

RSpec.describe Annotato::ColumnFormatter do
  let(:connection) { double("Connection") }
  let(:model) { double("Model") }
  let(:columns) do
    [
      double("Column", name: "id", sql_type: "bigint", default: nil, null: false),
      double("Column", name: "roles", sql_type: "character varying[]", default: [], null: false),
      double("Column", name: "status", sql_type: "integer", default: "draft", null: false)
    ]
  end
  let(:indexes) { [] }
  let(:enums) { { "status" => { "draft" => "0", "published" => "1" } } }

  before do
    allow(model).to receive(:table_name).and_return("users")
    allow(model).to receive(:primary_key).and_return("id")
    allow(model).to receive(:defined_enums).and_return(enums)
    allow(connection).to receive(:columns).with("users").and_return(columns)
    allow(connection).to receive(:indexes).with("users").and_return(indexes)
  end

  it "formats columns correctly" do
    result = described_class.format(model, connection)
    expect(result).to include(a_string_matching(/^#\s+id\s+:bigint\s+not null, primary key$/))
    expect(result).to include(a_string_matching(/^#\s+roles\s+:character varying\[\]\s+default\(\[\]\), not null, is an Array$/))
    expect(result.any? { |line| line =~ /status.*enum/ }).to be true
  end
end
