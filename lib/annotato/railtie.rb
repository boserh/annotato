# frozen_string_literal: true

require "rails/railtie"
require_relative "auto_annotate"

module Annotato
  class Railtie < ::Rails::Railtie
    rake_tasks do
      # Load all annotato rake tasks as before
      Dir[File.expand_path("../tasks/**/*.rake", __dir__)].each { |f| load f }

      # After migrating or rolling back, run annotato:models automatically (development only)
      AutoAnnotate.task_names(Rake::Task.tasks.map(&:name)).each do |name|
        Rake::Task[name].enhance do
          next unless AutoAnnotate.enabled?(Rails.env)

          Rake::Task["annotato:models"].reenable
          Rake::Task["annotato:models"].invoke
        end
      end
    end
  end
end
