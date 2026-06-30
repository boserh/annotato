# frozen_string_literal: true

module Annotato
  module WrapHelper
    MAX_LINE = 120

    # Produces one or more lines, each already prefixed with "#    "
    # First line: "#    where (..."
    # Next lines: "#          ..." (aligned under the "(")
    def wrap_sql(sql, first_prefix:, cont_prefix:, max_len: MAX_LINE)
      text = sql.to_s
      lines = []

      # If it already fits, keep it one-liner
      if (first_prefix.length + text.length + 1) <= max_len
        return "#{first_prefix}#{text})"
      end

      remaining = text.dup
      current_prefix = first_prefix

      while remaining.length > 0
        available = max_len - current_prefix.length - 1 # -1 for closing ")" on last line (or just safety)
        available = 20 if available < 20

        if remaining.length <= available
          lines << "#{current_prefix}#{remaining}"
          remaining = ""
          break
        end

        # Prefer breaking on logical operators within the window
        window = remaining[0, available]
        cut =
          window.rindex(" AND ") ||
          window.rindex(" OR ")  ||
          window.rindex(", ")    ||
          window.rindex(") ")    ||
          window.rindex(" ")     # last resort: whitespace

        # If we found a breakpoint, include it in the line (so operators stay visible)
        if cut
          # If we’re cutting on AND/OR/comma, keep that token at the end of the line when possible
          if window[cut, 5] == " AND " || window[cut, 4] == " OR "
            cut += (window[cut, 5] == " AND " ? 5 : 4)
          elsif window[cut, 2] == ", "
            cut += 2
          elsif window[cut, 2] == ") "
            cut += 2
          else
            cut += 1
          end
        else
          cut = available
        end

        lines << "#{current_prefix}#{remaining[0, cut].rstrip}"
        remaining = remaining[cut..].to_s.lstrip
        current_prefix = cont_prefix
      end

      # Close the paren on the last line
      lines[-1] = "#{lines[-1]})"

      lines.join("\n")
    end
  end
end
