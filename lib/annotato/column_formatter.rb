# frozen_string_literal: true

module Annotato
  class ColumnFormatter
    def self.format(model, connection)
      table_name = model.table_name
      primary_key = model.primary_key
      unique_indexes = connection.indexes(table_name).select(&:unique)
      enums = model.defined_enums

      columns_raw = connection.columns(table_name).map do |col|
        name = col.name
        type = col.sql_type
        options = []

        if !col.default.nil?
          if col.default.to_s.length > 60 && json_like?(col.default)
            formatted_default = format_json_default(col.default)
            options << "default(\n#{formatted_default}\n#  )"
          else
            options << "default(#{col.default.inspect})"
          end
        end

        options << "not null" unless col.null
        options << "primary key" if name == primary_key
        options << "is an Array" if type.end_with?("[]")
        options << "unique" if unique_indexes.any? { |idx| idx.columns == [name] }
        options << "enum" if enums.key?(name)

        [name, type, options.join(", ")]
      end

      name_width = columns_raw.map { |name, _, _| name.length }.max
      type_width = columns_raw.map { |_, type, _| type.length }.max

      columns_raw.map do |name, type, opts|
        line = "#  %-#{name_width}s :%-#{type_width}s" % [name, type]
        line += " #{opts}" unless opts.empty?
        line.rstrip
      end
    end

    def self.json_like?(value)
      value.is_a?(String) && value.strip.start_with?("{") && value.strip.end_with?("}")
    end

    def self.format_json_default(json_str)
      begin
        parsed = JSON.parse(json_str)
        parsed.map { |k, v| "#    \"#{k}\": #{v}" }.join(",\n")
      rescue JSON::ParserError
        "#    #{json_str.strip}"
      end
    end
  end
end
