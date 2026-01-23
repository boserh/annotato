# frozen_string_literal: true

module Annotato
  class IndexFormatter
    extend WrapHelper

    def self.format(conn, table_name)
      conn.indexes(table_name).map do |idx|
        cols_list = Array(idx.columns).join(',')
        unique_clause = idx.unique ? " unique" : ""

        where_clause = ""
        if idx.where
          where_clause = "\n" + wrap_sql(idx.where, first_prefix: "#    where (", cont_prefix: "#          ")
        end

        "#  #{idx.name} (#{cols_list})#{unique_clause}#{where_clause}"
      end
    end
  end
end
