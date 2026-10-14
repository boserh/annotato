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
      with_connection(model) { |conn| build_with(model, conn) }
    end

    # Uses the model's own connection (multi-database apps), and with_connection on
    # Rails 7.2+ where holding a permanent connection is deprecated.
    def self.with_connection(model, &block)
      model.respond_to?(:with_connection) ? model.with_connection(&block) : yield(model.connection)
    end
    private_class_method :with_connection

    def self.build_with(model, conn)
      table_name = model.table_name
      pg_enums = EnumFormatter.pg_enums(conn)

      lines = []
      lines << "== Annotato Schema Info"
      lines << "Table: #{table_name}"
      comment = conn.respond_to?(:table_comment) && conn.table_comment(table_name)
      lines << "Comment: #{comment}" if comment && !comment.empty?
      lines << ""

      lines << "Columns:"
      lines += ColumnFormatter.format(model, conn, pg_enums: pg_enums)

      enums = EnumFormatter.format(conn, conn.columns(table_name), pg_enums: pg_enums)
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
    private_class_method :build_with
  end
end
