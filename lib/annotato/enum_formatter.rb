# frozen_string_literal: true

module Annotato
  class EnumFormatter
    def self.format(model)
      return [] if model.defined_enums.empty?

      model.defined_enums.map do |attr, values|
        lines = ["#  #{attr}: {"]

        formatted_values = values.map do |key, val|
          if key.to_s == val.to_s
            "#{key}"
          else
            "#{key} (#{val})"
          end
        end

        lines += formatted_values.map { |v| "#    #{v}," }
        lines[-1] = lines[-1].chomp(',') # remove trailing comma from last line
        lines << "#  }"
        lines.join("\n")
      end
    end
  end
end
