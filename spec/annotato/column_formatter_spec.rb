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
      double("Column", name: "status", sql_type: "order_status", default: "pending", null: false),
      double("Column", name: "settings", sql_type: "jsonb", default: { theme: "dark" }.to_json, null: false),
      double("Column", name: "active", sql_type: "boolean", default: false, null: false),
      double("Column", name: "apples", sql_type: "float", default: 1.5, null: false)
    ]
  end

  let(:indexes) { [] }

  before do
    allow(model).to receive(:table_name).and_return("users")
    allow(model).to receive(:primary_key).and_return("id")
    allow(connection).to receive(:columns).with("users").and_return(columns)
    allow(connection).to receive(:indexes).with("users").and_return(indexes)
    # order_status is a native PG enum; all other types are not
    allow(connection).to receive(:adapter_name).and_return("PostgreSQL")
    allow(connection).to receive(:exec_query)
      .with(/pg_enum/, "SQL")
      .and_return([{ "type_name" => "order_status", "label" => "pending" }])
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

    # Ensure "enum" is noted for the status column (backed by order_status PG enum type)
    expect(result.any? { |l| l.include?("status") && l.include?("enum") }).to be true

    # Ensure theme appears in settings
    expect(result.any? { |l| l.include?("theme") }).to be true

    # Ensure default false is noted for active
    expect(result.any? { |l| l.include?("active") && l.include?("default(false)") }).to be true
    expect(result.any? { |l| l.include?("apples") && l.include?("default(1.5)") }).to be true
  end

  it "renders DB column comments when present" do
    commented = double(
      "Column", name: "fire", sql_type: "text", default: nil, null: false,
      comment: "Well, I like the way it burns"
    )
    blank = double("Column", name: "x", sql_type: "integer", default: nil, null: false, comment: "")
    allow(connection).to receive(:columns).with("users").and_return([commented, blank])

    result = described_class.format(model, connection)

    expect(result[0]).to include(%(comment: "Well, I like the way it burns"))
    expect(result[1]).not_to include("comment:")
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
    expect(closing_line).to match(/^#{"#" + ' ' * (indent_start - 1)}\]\),/)
  end

  it "wraps options onto a continuation line when the column line exceeds MAX_LINE" do
    # left = "#  " (3) + name (79) + " :" (2) + type (22) = 106 chars
    # 106 + " not null, unique" (17) = 123 > MAX_LINE (120) → must wrap
    long_name = "a_very_long_column_name_that_will_definitely_push_the_line_over_the_rubocop_limit"
    long_type = "character varying(255)"
    col = double("Column", name: long_name, sql_type: long_type, default: nil, null: false)
    allow(col).to receive(:respond_to?).with(:comment).and_return(false)
    allow(col).to receive(:respond_to?).with(:virtual?).and_return(false)
    allow(col).to receive(:respond_to?).with(:default_function).and_return(false)
    allow(connection).to receive(:columns).with("users").and_return([col])
    allow(connection).to receive(:indexes).with("users").and_return([
      double(name: "idx", columns: [long_name], unique: true, where: nil)
    ])

    result = described_class.format(model, connection)

    expect(result.size).to eq(2)
    expect(result[0]).not_to include("not null")
    expect(result[0].length).to be <= Annotato::WrapHelper::MAX_LINE
    expect(result[1]).to include("not null, unique")
  end
  it "shows database function defaults" do
    col = double("Column", name: "created_at", sql_type: "timestamp(6) without time zone",
                           default: nil, default_function: "now()", null: false)
    allow(connection).to receive(:columns).with("users").and_return([col])

    expect(described_class.format(model, connection, pg_enums: {}).first)
      .to end_with(":timestamp(6) without time zone default(now()), not null")
  end

  it "hides sequence defaults of serial columns" do
    col = double("Column", name: "id", sql_type: "integer", default: nil,
                           default_function: "nextval('audit_chats_id_seq'::regclass)", null: false)
    allow(connection).to receive(:columns).with("users").and_return([col])

    expect(described_class.format(model, connection, pg_enums: {}))
      .to eq(["#  id :integer not null, primary key"])
  end

  it "shows generated columns as generated, not as a default" do
    expr = "COALESCE(NULLIF((trade_name)::text, ''::text), (legal_name)::text)"
    col = double("Column", name: "official_name", sql_type: "character varying", default: nil,
                           default_function: expr, virtual?: true, null: true)
    allow(connection).to receive(:columns).with("users").and_return([col])

    expect(described_class.format(model, connection, pg_enums: {}))
      .to eq(["#  official_name :character varying generated(#{expr})"])
  end

  it "aligns a wrapped option line under the type column" do
    expr = "COALESCE(NULLIF((trade_name)::text, ''::text), (legal_name)::text)"
    columns = [
      double("Column", name: "official_name", sql_type: "character varying", default: nil,
                       default_function: expr, virtual?: true, null: true),
      double("Column", name: "years_in_business_total", sql_type: "integer", default: nil, null: true)
    ]
    allow(connection).to receive(:columns).with("users").and_return(columns)

    lines = described_class.format(model, connection, pg_enums: {})

    expect(lines[0]).to eq("#  official_name           :character varying")
    expect(lines[1]).to eq("#                          generated(#{expr})")
    expect(lines[1].index("generated")).to eq(lines[0].index(":"))
  end

  it "falls back to a short indent when the aligned continuation would still be too long" do
    col = double("Column", name: "n" * 60, sql_type: "character varying", default: nil,
                           default_function: "x" * 60, virtual?: true, null: true)
    allow(connection).to receive(:columns).with("users").and_return([col])

    lines = described_class.format(model, connection, pg_enums: {})

    expect(lines[1]).to eq("#    generated(#{'x' * 60})")
  end

  it "marks a column unique (partial) when its only unique index is partial" do
    allow(connection).to receive(:indexes).with("users").and_return([
      double(name: "idx_email_active", columns: ["email"], unique: true, where: "(deleted_at IS NULL)"),
      double(name: "idx_code", columns: ["code"], unique: true, where: nil)
    ])
    allow(connection).to receive(:columns).with("users").and_return([
      double("Column", name: "email", sql_type: "text", default: nil, null: true),
      double("Column", name: "code", sql_type: "text", default: nil, null: true)
    ])

    email, code = described_class.format(model, connection, pg_enums: {})
    expect(email).to end_with(":text unique (partial)")
    expect(code).to end_with(":text unique")
  end

  it "returns an empty array for a table without columns" do
    allow(connection).to receive(:columns).with("users").and_return([])

    expect(described_class.format(model, connection, pg_enums: {})).to eq([])
  end

  it "renders JSON defaults as valid, pretty-printed JSON" do
    col = double("Column", name: "data", sql_type: "jsonb", null: true,
                           default: { ids: [1, 2], nested: { off: nil, quote: %(say "hi") } }.to_json)
    allow(connection).to receive(:columns).with("users").and_return([col])

    lines = described_class.format(model, connection, pg_enums: {})
    body = lines.map { |l| l.sub(/\A#\s*/, "") }.join("\n")
    json = body[/default\((.*)\)\z/m, 1]

    expect(lines.first).to end_with("default({")
    expect(lines.last).to match(/^#\s+}\)$/)
    expect(JSON.parse(json)).to eq("ids" => [1, 2], "nested" => { "off" => nil, "quote" => %(say "hi") })
    expect(lines).to include(a_string_matching(/^#\s+1,$/))
  end
end
