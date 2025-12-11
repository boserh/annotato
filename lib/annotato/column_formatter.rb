# frozen_string_literal: true

require "json"

module Annotato
  class ColumnFormatter
    # Main entry: returns an array of comment lines per column, flattened.
    def self.format(model, connection)
      table_name     = model.table_name
      primary_key    = model.primary_key
      unique_indexes = connection.indexes(table_name).select(&:unique)
      enums          = model.defined_enums
      columns        = connection.columns(table_name)

      # Compute max widths for name and sql_type so that the table lines up.
      name_width = columns.map(&:name).map(&:length).max
      type_width = columns.map(&:sql_type).map(&:length).max

      columns.flat_map do |col|
        name = col.name
        type = col.sql_type

        # require "pry" if name == "allowed_statuses"
        # binding.pry if name == "allowed_statuses"
        # Build the left-hand side and calculate indent.
        left  = "#  %-#{name_width}s :%-#{type_width}s" % [name, type]
        # " default(" is 9 chars; +2 gives the extra gap.
        indent_size = left.length + 1
        indent_str  = " " * indent_size
        closing_indent_str  = " " * (indent_size - 2)

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
        opts << "enum"           if enums.key?(name)

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
          # single-line comment
          line = left
          line += " #{opts.join(', ')}" unless opts.empty?
          [line.rstrip]
        end
      end
    end

    # Returns nil (no default) or an Array of un-indented lines:
    #   ["[", "\"A\",", "\"B\"", "]"]   or   ["{", "\"k\":v,", ... , "}"]
    # If the value is empty array or hash, returns ["[]"] or ["{}"].
    def self.build_default_block(value)
      return nil if value.nil? || !value.is_a?(String)
      s = value.strip
      return nil unless s.start_with?("[") || s.start_with?("{")

      parsed = JSON.parse(s) rescue nil
      return nil unless parsed.is_a?(Array) || parsed.is_a?(Hash)

      if parsed.is_a?(Array)
        return if parsed.empty? # empty array → ["[]"]

        # Only a JSON array of strings?
        parsed.map.with_index do |e, i|
          comma = i == parsed.size - 1 ? "" : ","
          %Q{"#{e}"#{comma}}
        end
      else
        return if parsed.empty? # empty hash → ["{}"]

        # JSON hash → key/value pairs
        parsed.map.with_index do |(k, v), i|
          comma = i == parsed.size - 1 ? "" : ","
          %Q{"#{k}": #{v.inspect}#{comma}}
        end
      end
    end
  end
end
