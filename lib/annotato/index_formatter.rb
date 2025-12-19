# frozen_string_literal: true

module Annotato
  class IndexFormatter
    def self.format(conn, table_name)
      conn.indexes(table_name).map do |idx|
        cols_list = Array(idx.columns).join(',')
        unique_clause = idx.unique ? " unique" : ""
        where_clause = idx.where ? " where (#{idx.where})" : ""
        "#  #{idx.name} (#{cols_list})#{unique_clause}#{where_clause}"
      end
    end
  end
end
