# frozen_string_literal: true

require_relative "wrap_helper"

module Annotato
  class CheckConstraintFormatter
    extend WrapHelper

    def self.format(conn, table_name)
      # check_constraints exists since Rails 6.1 and not every adapter supports it.
      return [] unless conn.respond_to?(:check_constraints) && conn.supports_check_constraints?

      conn.check_constraints(table_name).sort_by(&:name).map do |chk|
        expr_clause = ""
        if chk.expression
          expr_clause = "\n" + wrap_sql(chk.expression, first_prefix: "#    (", cont_prefix: "#    ")
        end
        "#  #{chk.name}#{expr_clause}"
      end
    end
  end
end
