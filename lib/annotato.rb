# frozen_string_literal: true

require "annotato/version"

module Annotato
  autoload :AnnotationBuilder, "annotato/annotation_builder"
  autoload :AutoAnnotate,      "annotato/auto_annotate"
  autoload :ModelAnnotator,    "annotato/model_annotator"
end

require "annotato/railtie" if defined?(Rails::Railtie)
