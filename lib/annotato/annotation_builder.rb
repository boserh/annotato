# frozen_string_literal: true

require_relative "wrap_helper"
require_relative "column_formatter"
require_relative "index_formatter"
require_relative "trigger_formatter"
require_relative "line_formatter"
require_relative "enum_formatter"
require_relative "check_constraint_formatter"

module Annotato
  class AnnotationBuilder
    def self.build(model)
      conn = ActiveRecord::Base.connection
      table_name = model.table_name

      lines = []
      lines << "== Annotato Schema Info"
      lines << "Table: #{table_name}"
      lines << ""

      lines << "Columns:"
      lines += ColumnFormatter.format(model, conn)

      enums = EnumFormatter.format(model)
      unless enums.empty?
        lines << ""
        lines << "Enums:"
        lines += enums
      end

      indexes = IndexFormatter.format(conn, table_name)
      unless indexes.empty?
        lines << ""
        lines << "Indexes:"
        lines += indexes
      end

      triggers = TriggerFormatter.format(conn, table_name)
      unless triggers.empty?
        lines << ""
        lines << "Triggers:"
        lines += triggers
      end

      check_constraints = CheckConstraintFormatter.format(conn, table_name)
      unless check_constraints.empty?
        lines << ""
        lines << "Check Constraints:"
        lines += check_constraints
      end

      LineFormatter.format(lines)
    end
  end
end
