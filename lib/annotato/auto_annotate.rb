# frozen_string_literal: true

module Annotato
  # Decides when annotations are refreshed automatically after migrations.
  module AutoAnnotate
    # db:migrate, db:rollback and their per-database / up / down / redo variants.
    TASK_PATTERN = /\Adb:(?:migrate|rollback)(?::(?!status\z)\w+)?\z/

    # Only in development, so deploys and CI never rewrite model files.
    # ANNOTATO_SKIP=1 turns it off locally too.
    def self.enabled?(rails_env, env = ENV)
      return false if %w[1 true yes].include?(env["ANNOTATO_SKIP"].to_s.downcase)

      rails_env.to_s == "development"
    end

    def self.task_names(all_names)
      all_names.grep(TASK_PATTERN)
    end
  end
end
