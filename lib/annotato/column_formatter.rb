# frozen_string_literal: true

require "json"
require_relative "wrap_helper"

module Annotato
  class ColumnFormatter
    extend WrapHelper

    # Main entry: returns an array of comment lines per column, flattened.
    def self.format(model, connection)
      table_name     = model.table_name
      primary_key    = model.primary_key
      unique_indexes = connection.indexes(table_name).select(&:unique)
      columns        = connection.columns(table_name)

      # Collect native PG enum type names once up front (avoids N+1 queries).
      pg_enum_types = pg_enum_type_names(connection)

      # Compute max widths for name and sql_type so that the table lines up.
      name_width = columns.map(&:name).map(&:length).max
      type_width = columns.map(&:sql_type).map(&:length).max

      columns.flat_map do |col|
        name = col.name
        type = col.sql_type

        # Build the left-hand side and calculate indent.
        # Strip trailing padding spaces immediately — output must never have trailing whitespace.
        left = ("#  %-#{name_width}s :%-#{type_width}s" % [name, type]).rstrip
        # indent_size aligns multiline default content under the opening "default(" token.
        indent_size = left.length + 1
        indent_str  = " " * indent_size
        closing_indent_str = " " * (indent_size - 2)

        # Gather all options, pulling out default_lines if multiline.
        opts         = []
        default_block = build_default_block(col.default)
        if default_block
          opts << "__MULTILINE__"  # placeholder
        elsif !col.default.nil?
          opts << "default(#{col.default.inspect})"
        end
        opts << "not null"       unless col.null
        opts << "primary key"    if name == primary_key
        opts << "is an Array"    if type.end_with?("[]")
        opts << "unique"         if unique_indexes.any? { |idx| idx.columns == [name] }
        opts << "enum"           if pg_enum_types.include?(type.delete_suffix("[]"))
        opts << "comment: #{col.comment.inspect}" if col.respond_to?(:comment) && col.comment && !col.comment.empty?

        # Emit either a multiline block or a single line.
        if default_block
          # 1) opening line
          lines = ["#{left} default(#{col.default[0]}"]
          # 2) each interior line, prefixed by "# " + indent_str
          lines += default_block.map { |l| "# #{indent_str}#{l}" }
          # 3) closing line with trailing options
          closing = "# #{closing_indent_str}#{col.default[-1]})"
          trailing = opts.reject { |o| o == "__MULTILINE__" }
          closing += ", #{trailing.join(', ')}" unless trailing.empty?
          lines << closing
          lines
        else
          # single-line comment; wrap options onto continuation line if too long
          opts_str = opts.join(", ")
          line = opts_str.empty? ? left : "#{left} #{opts_str}"
          if line.length > WrapHelper::MAX_LINE && !opts_str.empty?
            [left, "#    #{opts_str}"]
          else
            [line]
          end
        end
      end
    end

    # Returns nil for non-JSON/empty values, or an Array of un-indented inner lines
    # for multiline formatting: e.g. ["\"A\",", "\"B\""] for a JSON array.
    def self.build_default_block(value)
      return nil if value.nil? || !value.is_a?(String)
      s = value.strip
      return nil unless s.start_with?("[") || s.start_with?("{")

      parsed = JSON.parse(s) rescue nil
      return nil unless parsed.is_a?(Array) || parsed.is_a?(Hash)

      if parsed.is_a?(Array)
        return nil if parsed.empty?

        # JSON array of strings
        parsed.map.with_index do |e, i|
          comma = i == parsed.size - 1 ? "" : ","
          %Q{"#{e}"#{comma}}
        end
      else
        return nil if parsed.empty?

        # JSON hash → key/value pairs
        parsed.map.with_index do |(k, v), i|
          comma = i == parsed.size - 1 ? "" : ","
          %Q{"#{k}": #{v.inspect}#{comma}}
        end
      end
    end

    # Fetches all native PostgreSQL enum type names in one query.
    # Returns a Set for O(1) membership checks.
    def self.pg_enum_type_names(connection)
      rows = connection.exec_query(
        "SELECT typname FROM pg_type WHERE typtype = 'e'",
        "SQL"
      )
      rows.map { |r| r["typname"] }.to_set
    end
    private_class_method :pg_enum_type_names
  end
end
