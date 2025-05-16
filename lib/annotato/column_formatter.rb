# frozen_string_literal: true

require 'json'

module Annotato
  class ColumnFormatter
    def self.format(model, connection)
      table_name = model.table_name
      primary_key = model.primary_key
      enums = model.defined_enums
      unique_indexes = connection.indexes(table_name).select(&:unique)
      columns = connection.columns(table_name)

      raw_data = columns.map do |col|
        name = col.name
        type = col.sql_type
        default = col.default
        opts = []

        opts << "default(#{default.inspect})" unless default.nil?
        opts << "not null" unless col.null
        opts << "primary key" if name == primary_key
        opts << "is an Array" if type.end_with?("[]")
        opts << "unique" if unique_indexes.any? { |idx| idx.columns == [name] }
        opts << "enum" if enums.key?(name)

        [name, type, default, opts]
      end

      name_width = raw_data.map { |name, *_| name.length }.max
      type_width = raw_data.map { |_, type, *_| type.length }.max

      raw_data.flat_map do |name, type, default, opts|
        base_line = "#  %-#{name_width}s :%-#{type_width}s" % [name, type]
        indent = ' ' * (base_line.length + 1)

        if multiline_default?(default)
          formatted_defaults = format_multiline_default(default)
          remaining_opts = opts.reject { |o| o.start_with?("default(") }

          lines = []
          lines << "#{base_line} default(["
          formatted_defaults.each do |v|
            lines << "#{'#' + indent}#{v}"
          end

          closing = "#{'#' + ' ' * (indent.length - 1)}]),"
          closing += " #{remaining_opts.join(', ')}" unless remaining_opts.empty?
          lines << closing.rstrip
          lines
        else
          line = base_line
          line += " #{opts.join(', ')}" unless opts.empty?
          line.rstrip
        end
      end
    end

    def self.multiline_default?(value)
      value.is_a?(String) && value.strip.start_with?("[") && value.strip.end_with?("]") && value.include?(",")
    end

    def self.format_multiline_default(value)
      parsed = JSON.parse(value)
      return [value] unless parsed.is_a?(Array)

      items = parsed.is_a?(Array) && parsed[0].is_a?(Array) ? parsed[0] : parsed

      items.map.with_index do |item, idx|
        comma = idx == items.size - 1 ? "" : ","
        "#{item.to_json}#{comma}"
      end
    rescue JSON::ParserError
      [value]
    end
  end
end
