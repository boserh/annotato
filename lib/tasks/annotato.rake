# lib/tasks/annotato.rake

require "annotato/model_annotator"

namespace :annotato do
  desc "Annotate models with schema info. Pass MODEL=name or comma-separated list"
  task :models, [:MODEL] => :environment do |t, args|
    # Parse MODEL argument into an array of model names, if given
    model_list = args[:MODEL]&.split(",")&.map(&:strip)

    annotator = Annotato::ModelAnnotator.new

    if model_list && model_list.any?
      # Constantize each name and annotate only those classes
      model_list.map(&:constantize).each do |klass|
        annotator.run(klass)
      end
    else
      # No MODEL passed → annotate all models
      annotator.run
    end
  end
end
