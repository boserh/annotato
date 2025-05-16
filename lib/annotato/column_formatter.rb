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

        options << "default(#{col.default.inspect})" unless col.default.nil?
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
  end
end
