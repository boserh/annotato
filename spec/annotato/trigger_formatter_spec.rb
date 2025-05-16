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
    allow(connection).to receive(:exec_query).and_return(result_set)

    result = described_class.format(connection, "users")
    expect(result).to include("#  audit_trigger_row")
    expect(result).to include("#  update_timestamp")
  end
end
