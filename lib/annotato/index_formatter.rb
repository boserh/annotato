# frozen_string_literal: true

require_relative "wrap_helper"

module Annotato
  class IndexFormatter
    extend WrapHelper

    def self.format(conn, table_name)
      conn.indexes(table_name).sort_by(&:name).map do |idx|
        cols_list = Array(idx.columns).map { |col| with_order(idx, col) }.join(',')
        unique_clause = idx.unique ? " unique" : ""

        where_clause = ""
        if idx.where
          where_clause = "\n" + wrap_sql(idx.where, first_prefix: "#    where (", cont_prefix: "#          ")
        end

        "#  #{idx.name} (#{cols_list})#{unique_clause}#{extras(idx)}#{where_clause}"
      end
    end

    # Index method (other than the default btree), INCLUDE columns and NULLS NOT DISTINCT.
    # Guarded with respond_to? because these attributes vary across Rails versions.
    def self.extras(idx)
      parts = []
      using = idx.respond_to?(:using) && idx.using
      parts << "using #{using}" if using && using.to_s != "btree"
      include_cols = idx.respond_to?(:include) && idx.include
      parts << "include (#{Array(include_cols).join(',')})" if include_cols && !Array(include_cols).empty?
      parts << "nulls not distinct" if idx.respond_to?(:nulls_not_distinct) && idx.nulls_not_distinct
      parts.empty? ? "" : " #{parts.join(' ')}"
    end
    private_class_method :extras

    def self.with_order(idx, col)
      return col unless idx.respond_to?(:orders)

      order = idx.orders.is_a?(Hash) ? idx.orders[col.to_s] || idx.orders[col.to_sym] : idx.orders
      order ? "#{col} #{order.to_s.upcase}" : col
    end
    private_class_method :with_order
  end
end
