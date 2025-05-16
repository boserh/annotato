# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  minimum_coverage 90
end

require "bundler/setup"
require "rspec"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Run specs in random order to surface order dependencies.
  config.order = :random

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface performance issues.
  config.profile_examples = 10

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Allow focusing on specific tests by tagging with :focus
  config.filter_run_when_matching :focus

  # Optional: treat warnings as errors (comment out if too noisy)
  # config.warnings = true

  # If you want to use color in the output
  config.color = true
  config.tty = true

  # Optional formatter for documentation output
  config.formatter = :documentation
end
