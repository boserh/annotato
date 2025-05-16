# frozen_string_literal: true

module Annotato
  class EnumFormatter
    def self.format(model)
      return [] if model.defined_enums.empty?

      model.defined_enums.map do |attr, values|
        # Check if all values equal keys (strings)
        if values.values.all? { |v| v == v.to_s && values.keys.include?(v) }
          enum_str = values.keys.join(", ")
        else
          enum_str = values.map { |k, v| "#{k} (#{v})" }.join(", ")
        end

        "#  #{attr}: { #{enum_str} }"
      end
    end
  end
end
