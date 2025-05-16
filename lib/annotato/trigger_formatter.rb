# frozen_string_literal: true

module Annotato
  class TriggerFormatter
    def self.format(conn, table_name)
      conn.exec_query(<<~SQL).map { |r| "#  #{r['tgname']}" }
        SELECT tgname FROM pg_trigger
        WHERE tgrelid = '#{table_name}'::regclass
          AND NOT tgisinternal;
      SQL
    end
  end
end
