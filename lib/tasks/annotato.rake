# lib/tasks/annotato.rake

require "annotato/model_annotator"

namespace :annotato do
  # Model names come from the task args and/or ENV["MODEL"]. Rake splits task args
  # on commas, so annotato:models[User,Admin::Account] arrives as MODEL + extras.
  model_names = lambda do |args|
    [args[:MODEL], *args.extras, ENV["MODEL"]]
      .compact
      .flat_map { |names| names.split(",") }
      .map(&:strip)
      .reject(&:empty?)
      .uniq
  end

  desc "Annotate models with schema info. Pass MODEL=name or comma-separated list"
  task :models, [:MODEL] => :environment do |_t, args|
    names = model_names.call(args)
    annotator = Annotato::ModelAnnotator.new

    if names.any?
      annotator.run_named(names)
    else
      # No MODEL passed → annotate all models
      annotator.run
    end

    puts "✅ Annotato completed"
  end

  desc "Check that model annotations are up to date (no files are written); fails if any are outdated"
  task :check, [:MODEL] => :environment do |_t, args|
    names = model_names.call(args)
    annotator = Annotato::ModelAnnotator.new(check: true)
    names.any? ? annotator.run_named(names) : annotator.run

    if annotator.outdated.any?
      abort "❌ #{annotator.outdated.size} outdated annotation(s). Run `rake annotato:models` to update."
    end

    puts "✅ Annotations are up to date"
  end
end
