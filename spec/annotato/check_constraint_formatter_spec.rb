# frozen_string_literal: true

require "spec_helper"
require "annotato/check_constraint_formatter"

RSpec.describe Annotato::CheckConstraintFormatter do
  let(:connection) { double("Connection") }

  it "formats indexes correctly" do
    check_constraints = [
      double("CheckConstraint", table_name: "users", name: "chk_positive_age", expression: "age > 0"),
      double("CheckConstraint", table_name: "users", name: "chk_valid_status", expression: "((((status)::text = 'deleted'::text) AND (deleted_at IS NOT NULL)) OR (((status)::text <> 'deleted'::text) AND (deleted_at IS NULL) AND (active = true)))")
    ]
    allow(connection).to receive(:check_constraints).with("users").and_return(check_constraints)

    result = described_class.format(connection, "users")

    expect(result).to include("#  chk_positive_age\n#    (age > 0)")
    expect(result).to include("#  chk_valid_status\n#    (((((status)::text = 'deleted'::text) AND (deleted_at IS NOT NULL)) OR (((status)::text <> 'deleted'::text) AND\n#    (deleted_at IS NULL) AND (active = true))))")
  end
end
