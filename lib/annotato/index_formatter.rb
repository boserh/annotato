# frozen_string_literal: true

module Annotato
  class IndexFormatter
    def self.format(conn, table_name)
      conn.indexes(table_name).map do |idx|
        cols = Array(idx.columns)
        "#  #{idx.name} (#{cols.join(', ')})"
      end
    end
  end
end
