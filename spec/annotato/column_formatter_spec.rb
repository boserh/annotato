# frozen_string_literal: true

require "spec_helper"
require "annotato/column_formatter"

RSpec.describe Annotato::ColumnFormatter do
  let(:connection) { double("Connection") }
  let(:model) { double("Model") }

  let(:columns) do
    [
      double("Column", name: "id", sql_type: "integer", default: nil, null: false),
      double("Column", name: "allowed_statuses", sql_type: "jsonb", default: [
        "ARRIVED_AT_PICKUP", "PICKED_UP", "PICKUP_APPT_CHANGED"
      ].to_json, null: false),
      double("Column", name: "contacts", sql_type: "jsonb", default: {
        email: false,
        phone: false,
        emergency_email: false
      }.to_json, null: false),
      double("Column", name: "tags", sql_type: "character varying[]", default: [].to_json, null: false),
      double("Column", name: "spans", sql_type: "jsonb", default: {}.to_json, null: false),
      double("Column", name: "status", sql_type: "integer", default: "pending", null: false),
      double("Column", name: "settings", sql_type: "jsonb", default: { theme: "dark" }.to_json, null: false)
    ]
  end

  let(:indexes) { [] }
  let(:enums) do
    {
      "status" => { "pending" => "0", "active" => "1" },
      "allowed" => { "yes" => "yes", "no" => "no" },
    }
  end

  before do
    allow(model).to receive(:table_name).and_return("users")
    allow(model).to receive(:primary_key).and_return("id")
    allow(model).to receive(:defined_enums).and_return(enums)
    allow(connection).to receive(:columns).with("users").and_return(columns)
    allow(connection).to receive(:indexes).with("users").and_return(indexes)
  end

  it "formats and aligns multiline defaults correctly" do
    result = described_class.format(model, connection)

    # Find allowed_statuses lines
    allowed_index = result.find_index { |line| line.include?("allowed_statuses") }
    expect(allowed_index).to be_truthy

    expect(result[allowed_index]).to match(/^#\s+allowed_statuses\s+:jsonb\s+default\(\[$/)
    expect(result[allowed_index + 1]).to match(/^#\s+"ARRIVED_AT_PICKUP",$/)
    expect(result[allowed_index + 2]).to match(/^#\s+"PICKED_UP",$/)
    expect(result[allowed_index + 3]).to match(/^#\s+"PICKUP_APPT_CHANGED"$/)
    expect(result[allowed_index + 4]).to match(/^#\s+\]\), not null$/)

    # Ensure "is an Array" is mentioned
    expect(result.any? { |l| l.include?("is an Array") }).to be true

    # Ensure "enum" is noted for status
    expect(result.any? { |l| l.include?("status") && l.include?("enum") }).to be true

    # Ensure theme appears in settings
    expect(result.any? { |l| l.include?("theme") }).to be true
  end

  it "aligns multiline default values with consistent indentation and comment prefix" do
    result = described_class.format(model, connection)

    allowed_index = result.find_index { |line| line.include?("allowed_statuses") }
    expect(allowed_index).to be_truthy

    opening_line = result[allowed_index]
    indent_start = opening_line.index("default([")

    multiline_lines = result[(allowed_index + 1)..]

    # Select only lines with default values (those containing JSON strings like "...")
    value_lines = multiline_lines.select { |line| line.match(/^#\s+"[^"]/) }

    # All value lines should start with correct comment prefix and indentation
    value_lines.each do |line|
      expect(line).to match(/^#{"#" + ' ' * (indent_start + 1)}"/)
    end

    # Closing line should be correctly indented
    closing_line = multiline_lines.find { |line| line.include?("]),") }
    expect(closing_line).to match(/^#{"#" + ' ' * (indent_start-1)}\]\),/)
  end
end
