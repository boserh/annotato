# frozen_string_literal: true

require_relative "adapter"

module Annotato
  # Formats PostgreSQL native enum type definitions for columns whose sql_type
  # refers to a custom DB enum (e.g. `access_link_category`). Queries pg_enum
  # directly so the output reflects the actual database definition, not the
  # ActiveRecord-level enum mapping already visible in the model source.
  class EnumFormatter
    def self.format(conn, columns, pg_enums: pg_enums(conn))
      columns.flat_map do |col|
        labels = pg_enums[col.sql_type.delete_suffix("[]")]
        next [] unless labels

        lines = ["#  #{col.name} (#{col.sql_type}): ["]
        labels.each_with_index do |label, i|
          comma = i == labels.size - 1 ? "" : ","
          lines << "#    #{label}#{comma}"
        end
        lines << "#  ]"
        lines
      end
    end

    # Returns { type_name => [labels in sort order] } for every native PG enum, in one query.
    # Keys come from format_type(), the same function PostgreSQL uses for a column's sql_type,
    # so types outside the search_path are schema-qualified exactly as in the column.
    # Returns {} for non-PostgreSQL adapters.
    def self.pg_enums(conn)
      return {} unless Adapter.postgresql?(conn)

      rows = conn.exec_query(
        "SELECT format_type(t.oid, NULL) AS type_name, e.enumlabel AS label " \
        "FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid " \
        "ORDER BY t.oid, e.enumsortorder",
        "SQL"
      )
      rows.each_with_object({}) do |r, acc|
        (acc[r["type_name"]] ||= []) << r["label"]
      end
    end
  end
end
