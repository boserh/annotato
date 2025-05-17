# frozen_string_literal: true

require "active_record"
require_relative "column_formatter"
require_relative "annotation_builder"

module Annotato
  class ModelAnnotator
    def initialize(output: $stdout)
      @output = output
    end

    def run(one_model = nil)
      mtd = one_model ? [one_model] : models

      mtd.each do |model|
        next unless model.table_exists?

        annotation = AnnotationBuilder.build(model)
        write_annotation(model, annotation)
      end
      @output.puts "✅ Annotato completed"
    end

    private

      def models
        Rails.application.eager_load!
        # All AR models, but skip STI subclasses (only keep base classes)
        ActiveRecord::Base.descendants
          .reject(&:abstract_class?)
          .select { |m| m.base_class == m }
      end

      def model_file(model)
        file = model.instance_method(:initialize).source_location&.first

        if file.nil? || file.include?("/gems/")
          Object.const_source_location(model.name)&.first
        else
          file
        end
      end

      def write_annotation(model, annotation)
        file = model_file(model)
        return unless file && File.exist?(file)

        content = File.read(file).dup   # <--- duplicate string to avoid FrozenError

        # Extract the old Annotato annotation block if it exists
        old_annotation = content[/^# == Annotato Schema Info.*?(?=^class|\z)/m]

        # Skip writing if the annotation hasn't changed
        if old_annotation && old_annotation.strip == annotation.strip
          @output.puts "ℹ️  Skipped #{model.name} — annotation unchanged"
          return
        end

        # Remove old Annotato blocks
        content.gsub!(/^# == Annotato Schema Info.*?(?=^class|\z)/m, "")
        content.gsub!(/^# == Schema Information.*?(?=^class|\z)/m, "")
        content.rstrip!

        # Verify the class definition exists before appending annotation
        unless content.match?(/class\s+\w+/)
          @output.puts "⚠️  Skipped #{model.name} — class not found in file"
          return
        end

        # Append the new annotation at the end of the file
        content += "\n\n#{annotation}\n"
        File.write(file, content)

        @output.puts "✍️  Annotated #{model.name}"
      end
  end
end
