# frozen_string_literal: true

module Annotato
  class TriggerFormatter
    def self.format(conn, table_name)
      rows = case conn.adapter_name.downcase
             when "postgresql"
               conn.exec_query(
                 "SELECT tgname AS name FROM pg_trigger WHERE tgrelid = $1::regclass AND NOT tgisinternal",
                 "SQL", [table_name]
               )
             when "mysql2", "mysql", "trilogy"
               conn.exec_query(
                 "SELECT TRIGGER_NAME AS name FROM information_schema.TRIGGERS " \
                 "WHERE EVENT_OBJECT_SCHEMA = DATABASE() AND EVENT_OBJECT_TABLE = ?",
                 "SQL", [table_name]
               )
             when "sqlite3"
               conn.exec_query(
                 "SELECT name FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ?",
                 "SQL", [table_name]
               )
             else
               return []
             end

      rows.map { |r| "#  #{r['name']}" }
    end
  end
end
