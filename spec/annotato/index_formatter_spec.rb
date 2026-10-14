# frozen_string_literal: true

require "spec_helper"
require "annotato/index_formatter"

RSpec.describe Annotato::IndexFormatter do
  let(:connection) { double("Connection") }

  it "formats indexes correctly" do
    indexes = [
      double("Index", name: "index_users_on_email", columns: ["email"], unique: true, where: nil),
      double("Index", name: "unique_index_on_name", columns: ["name"], unique: false, where: "((((type)::text = ANY (ARRAY[('CarrierCompany'::character varying)::text, ('BrokerCompany'::character varying)::text])) AND (verified = true)))")
    ]
    allow(connection).to receive(:indexes).with("users").and_return(indexes)

    result = described_class.format(connection, "users")
    expect(result).to include("#  index_users_on_email (email) unique")
    expect(result).to include("#  unique_index_on_name (name)\n#    where (((((type)::text = ANY (ARRAY[('CarrierCompany'::character varying)::text,\n#          ('BrokerCompany'::character varying)::text])) AND (verified = true))))")
  end
end

RSpec.describe Annotato::IndexFormatter, "index details" do
  let(:connection) { double("Connection") }

  def index(**attrs)
    double("Index", { columns: ["email"], unique: false, where: nil, using: :btree, include: nil,
                      orders: {}, nulls_not_distinct: nil }.merge(attrs))
  end

  it "shows the index method unless it is btree" do
    allow(connection).to receive(:indexes).with("users").and_return([
      index(name: "idx_tags", columns: ["tags"], using: :gin),
      index(name: "idx_email")
    ])

    expect(described_class.format(connection, "users")).to eq([
      "#  idx_email (email)",
      "#  idx_tags (tags) using gin"
    ])
  end

  it "shows column order, INCLUDE columns and NULLS NOT DISTINCT" do
    allow(connection).to receive(:indexes).with("users").and_return([
      index(name: "idx", columns: %w[email created_at], unique: true, orders: { "created_at" => :desc },
            include: %w[name], nulls_not_distinct: true)
    ])

    expect(described_class.format(connection, "users"))
      .to eq(["#  idx (email,created_at DESC) unique include (name) nulls not distinct"])
  end

  it "applies a single order to every column" do
    allow(connection).to receive(:indexes).with("users").and_return([
      index(name: "idx", columns: %w[a b], orders: :desc)
    ])

    expect(described_class.format(connection, "users")).to eq(["#  idx (a DESC,b DESC)"])
  end
end
