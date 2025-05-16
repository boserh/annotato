# frozen_string_literal: true

module Annotato
  class LineFormatter
    def self.format(lines)
      lines.map do |line|
        line.strip.empty? ? "#" : (line.start_with?("#") ? line : "# #{line.rstrip}")
      end.join("\n")
    end
  end
end
