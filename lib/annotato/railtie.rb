# frozen_string_literal: true

require "rails/railtie"

module Annotato
  class Railtie < ::Rails::Railtie
    rake_tasks do
      Dir[File.expand_path("../tasks/**/*.rake", __dir__)].each { |f| load f }
    end
  end
end
