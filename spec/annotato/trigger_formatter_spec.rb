# frozen_string_literal: true

require "spec_helper"
require "annotato/trigger_formatter"

RSpec.describe Annotato::TriggerFormatter do
  let(:connection) { double("Connection") }

  it "formats triggers correctly" do
    result_set = [
      { "tgname" => "audit_trigger_row" },
      { "tgname" => "update_timestamp" }
    ]
    allow(connection).to receive(:exec_query)
      .with(/pg_trigger/, "SQL", ["users"])
      .and_return(result_set)

    result = described_class.format(connection, "users")
    expect(result).to include("#  audit_trigger_row")
    expect(result).to include("#  update_timestamp")
  end

  it "uses a parameterized query (no string interpolation)" do
    expect(connection).to receive(:exec_query)
      .with(
        "SELECT tgname FROM pg_trigger WHERE tgrelid = $1::regclass AND NOT tgisinternal",
        "SQL",
        ["orders"]
      ).and_return([])

    described_class.format(connection, "orders")
  end
end
