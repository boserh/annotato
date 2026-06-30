# frozen_string_literal: true

module Annotato
  # Formats PostgreSQL native enum type definitions for columns whose sql_type
  # refers to a custom DB enum (e.g. `access_link_category`). Queries pg_enum
  # directly so the output reflects the actual database definition, not the
  # ActiveRecord-level enum mapping already visible in the model source.
  class EnumFormatter
    def self.format(conn, columns)
      # Collect columns backed by a native PG enum type.
      enum_columns = columns.select { |col| pg_enum_type?(conn, col.sql_type) }
      return [] if enum_columns.empty?

      enum_columns.flat_map do |col|
        labels = pg_enum_labels(conn, col.sql_type)
        lines = ["#  #{col.name} (#{col.sql_type}): ["]
        labels.each_with_index do |label, i|
          comma = i == labels.size - 1 ? "" : ","
          lines << "#    #{label}#{comma}"
        end
        lines << "#  ]"
        lines
      end
    end

    private_class_method def self.pg_enum_type?(conn, sql_type)
      # Strip array suffix (e.g. "my_enum[]") before checking.
      type_name = sql_type.delete_suffix("[]")
      result = conn.exec_query(
        "SELECT 1 FROM pg_type WHERE typname = $1 AND typtype = 'e' LIMIT 1",
        "SQL",
        [type_name]
      )
      result.any?
    end

    private_class_method def self.pg_enum_labels(conn, sql_type)
      type_name = sql_type.delete_suffix("[]")
      conn.exec_query(
        "SELECT e.enumlabel FROM pg_enum e " \
        "JOIN pg_type t ON e.enumtypid = t.oid " \
        "WHERE t.typname = $1 AND t.typtype = 'e' " \
        "ORDER BY e.enumsortorder",
        "SQL",
        [type_name]
      ).map { |r| r["enumlabel"] }
    end
  end
end
