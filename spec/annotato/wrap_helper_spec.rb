# frozen_string_literal: true

require "spec_helper"
require "annotato/wrap_helper"

RSpec.describe Annotato::WrapHelper do
  let(:helper) { Class.new { extend Annotato::WrapHelper } }

  it "keeps short SQL on one line" do
    expect(helper.wrap_sql("a > 1", first_prefix: "#    (", cont_prefix: "#    ")).to eq("#    (a > 1)")
  end

  it "never breaks inside a quoted literal" do
    # The last " AND " inside the 53-char window is inside the literal.
    literal = "'aa AND bb AND cc AND dd AND ee'"
    sql = "x = 1 AND note = #{literal} AND y = 2"

    lines = helper.wrap_sql(sql, first_prefix: "#    (", cont_prefix: "#    ", max_len: 60).split("\n")

    expect(lines).to eq(["#    (x = 1 AND", "#    note = #{literal} AND y = 2)"])
  end

  it "never emits an empty continuation line" do
    sql = " #{'x' * 70} #{'y' * 70}"

    lines = helper.wrap_sql(sql, first_prefix: "#    (", cont_prefix: "#    ", max_len: 60).split("\n")

    expect(lines).not_to include(a_string_matching(/\A#\s*\(?\z/))
  end
end
