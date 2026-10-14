# frozen_string_literal: true

module Annotato
  module WrapHelper
    MAX_LINE = 120
    # Preferred break points, best first; the token stays at the end of the line.
    BREAK_TOKENS = [" AND ", " OR ", ", ", ") ", " "].freeze

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

        # Prefer breaking on logical operators within the window; hard cut if none.
        cut = find_break(remaining[0, available]) || available

        lines << "#{current_prefix}#{remaining[0, cut].rstrip}"
        remaining = remaining[cut..].to_s.lstrip
        current_prefix = cont_prefix
      end

      # Close the paren on the last line
      lines[-1] = "#{lines[-1]})"

      lines.join("\n")
    end

    private

    # Position right after the best break token in window, or nil.
    # Never breaks at position 0 (would emit an empty line) or inside a quoted SQL literal.
    def find_break(window)
      BREAK_TOKENS.each do |token|
        pos = window.rindex(token)
        while pos && pos.positive?
          return pos + token.length unless inside_quotes?(window, pos)

          pos = window.rindex(token, pos - 1)
        end
      end
      nil
    end

    def inside_quotes?(text, pos)
      text[0, pos].count("'").odd?
    end
  end
end
