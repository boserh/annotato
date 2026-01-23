# frozen_string_literal: true

module Annotato
  class CheckConstraintFormatter
    extend WrapHelper

    def self.format(conn, table_name)
      conn.check_constraints(table_name).map do |chk|
        expr_clause = ""
        if chk.expression
          expr_clause = "\n" + wrap_sql(chk.expression, first_prefix: "#    (", cont_prefix: "#    ")
        end
        "#  #{chk.name}#{expr_clause}"
      end
    end
  end
end
