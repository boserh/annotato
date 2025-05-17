# frozen_string_literal: true

require "rails/railtie"

module Annotato
  class Railtie < ::Rails::Railtie
    rake_tasks do
      # Load all annotato rake tasks as before
      Dir[File.expand_path("../tasks/**/*.rake", __dir__)].each { |f| load f }

      # After db:migrate finishes, run annotato:models automatically
      Rake::Task["db:migrate"].enhance do
        Rake::Task["annotato:models"].reenable
        Rake::Task["annotato:models"].invoke
      end
    end
  end
end
