# frozen_string_literal: true

require "spec_helper"
require "annotato/index_formatter"

RSpec.describe Annotato::IndexFormatter do
  let(:connection) { double("Connection") }

  it "formats indexes correctly" do
    indexes = [
      double("Index", name: "index_users_on_email", columns: ["email"], unique: true, where: nil),
      double("Index", name: "unique_index_on_name", columns: ["name"], unique: false, where: "name IS NOT NULL")
    ]
    allow(connection).to receive(:indexes).with("users").and_return(indexes)

    result = described_class.format(connection, "users")
    expect(result).to include("#  index_users_on_email (email) unique")
    expect(result).to include("#  unique_index_on_name (name) where (name IS NOT NULL)")
  end
end
