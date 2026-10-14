# frozen_string_literal: true

require "json"
require_relative "wrap_helper"
require_relative "enum_formatter"

module Annotato
  class ColumnFormatter
    extend WrapHelper

    # Main entry: returns an array of comment lines per column, flattened.
    def self.format(model, connection, pg_enums: EnumFormatter.pg_enums(connection))
      table_name     = model.table_name
      primary_key    = model.primary_key
      unique_indexes = connection.indexes(table_name).select(&:unique)
      columns        = connection.columns(table_name)
      return [] if columns.empty?

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
        elsif generated?(col)
          opts << "generated(#{col.default_function})"
        elsif show_default_function?(col)
          opts << "default(#{col.default_function})"
        end
        opts << "not null"       unless col.null
        opts << "primary key"    if name == primary_key
        opts << "is an Array"    if type.end_with?("[]")
        unique_flag = unique_option(unique_indexes, name)
        opts << unique_flag      if unique_flag
        opts << "enum"           if pg_enums.key?(type.delete_suffix("[]"))
        opts << "comment: #{col.comment.inspect}" if col.respond_to?(:comment) && col.comment && !col.comment.empty?

        # Emit either a multiline block or a single line.
        if default_block
          # 1) opening line
          lines = ["#{left} default(#{default_block[:open]}"]
          # 2) each interior line, prefixed by "# " + indent_str
          lines += default_block[:lines].map { |l| "# #{indent_str}#{l}" }
          # 3) closing line with trailing options
          closing = "# #{closing_indent_str}#{default_block[:close]})"
          trailing = opts.reject { |o| o == "__MULTILINE__" }
          closing += ", #{trailing.join(', ')}" unless trailing.empty?
          lines << closing
          lines
        else
          # single-line comment; wrap options onto continuation line if too long
          opts_str = opts.join(", ")
          line = opts_str.empty? ? left : "#{left} #{opts_str}"
          if line.length > WrapHelper::MAX_LINE && !opts_str.empty?
            # Align the continuation under the type column so it reads as part of this column;
            # fall back to a short indent if that still doesn't fit.
            aligned = "##{' ' * (left.index(':') - 1)}#{opts_str}"
            [left, aligned.length <= WrapHelper::MAX_LINE ? aligned : "#    #{opts_str}"]
          else
            [line]
          end
        end
      end
    end

    # "unique" for a full single-column unique index; "unique (partial)" when every such
    # index has a WHERE clause (uniqueness holds only for some rows, see Indexes section).
    def self.unique_option(unique_indexes, name)
      indexes = unique_indexes.select { |idx| idx.columns == [name] }
      return if indexes.empty?

      indexes.any? { |idx| idx.where.to_s.empty? } ? "unique" : "unique (partial)"
    end
    private_class_method :unique_option

    # Generated columns (GENERATED ALWAYS AS ... ): Rails stores the expression in default_function.
    def self.generated?(col)
      col.respond_to?(:virtual?) && col.virtual? && !col.default_function.nil?
    end
    private_class_method :generated?

    # Function defaults like now() are shown; sequence defaults of serial columns
    # (nextval('users_id_seq'::regclass)) are implied by the type and only add noise.
    def self.show_default_function?(col)
      return false unless col.respond_to?(:default_function) && col.default_function

      !col.default_function.start_with?("nextval(")
    end
    private_class_method :show_default_function?

    # Returns nil for non-JSON/empty values, or { open:, close:, lines: } for multiline
    # formatting, where lines are the un-indented inner lines of the pretty-printed JSON:
    # e.g. { open: "[", close: "]", lines: ["\"A\",", "\"B\""] } for a JSON array.
    def self.build_default_block(value)
      return nil if value.nil? || !value.is_a?(String)
      s = value.strip
      return nil unless s.start_with?("[") || s.start_with?("{")

      parsed = JSON.parse(s) rescue nil
      return nil unless parsed.is_a?(Array) || parsed.is_a?(Hash)
      return nil if parsed.empty?

      pretty = JSON.pretty_generate(parsed).lines.map(&:rstrip)
      {
        open:  pretty.first,
        close: pretty.last,
        lines: pretty[1..-2].map { |l| l.delete_prefix("  ") }
      }
    end
  end
end
