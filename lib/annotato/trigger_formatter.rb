# frozen_string_literal: true

module Annotato
  class TriggerFormatter
    def self.format(conn, table_name)
      conn.exec_query(
        "SELECT tgname FROM pg_trigger WHERE tgrelid = $1::regclass AND NOT tgisinternal",
        "SQL",
        [table_name]
      ).map { |r| "#  #{r['tgname']}" }
    end
  end
end
