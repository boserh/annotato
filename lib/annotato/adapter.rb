# frozen_string_literal: true

module Annotato
  # Normalizes ActiveRecord adapter names ("PostgreSQL", "PostGIS", "Mysql2",
  # "Trilogy", "SQLite", ...) into a small set of symbols.
  module Adapter
    def self.kind(conn)
      case conn.adapter_name.downcase
      when /postg/                    then :postgresql
      when /mysql|trilogy/            then :mysql
      when /sqlite/                   then :sqlite
      end
    end

    def self.postgresql?(conn)
      kind(conn) == :postgresql
    end
  end
end
