require "annotato/model_annotator"

namespace :annotato do
  desc "Annotate models with schema info"
  task models: :environment do
    Annotato::ModelAnnotator.new.run
  end
end
