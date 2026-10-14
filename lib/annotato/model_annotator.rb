# frozen_string_literal: true

require "active_record"
require_relative "column_formatter"
require_relative "annotation_builder"

module Annotato
  class ModelAnnotator
    # A block is its header line plus every directly following comment line.
    # Matching stops at the first non-comment line (blank lines right after the block are
    # consumed too), so code after the block is never touched.
    ANNOTATO_BLOCK = /^# == Annotato Schema Info\n(?:#.*(?:\n|\z))*\n*/
    LEGACY_BLOCK   = /^# == Schema Information\n(?:#.*(?:\n|\z))*\n*/

    # Names of models whose annotation is missing or outdated (filled in check mode).
    attr_reader :outdated

    # check: true reports outdated annotations without writing any file.
    def initialize(output: $stdout, check: false)
      @output   = output
      @check    = check
      @outdated = []
    end

    def run(one_model = nil)
      mtd = one_model ? [one_model] : models

      mtd.each do |model|
        next unless model.table_exists?

        annotation = AnnotationBuilder.build(model)
        write_annotation(model, annotation)
      end
    end

    # Annotates models given by name (e.g. ["User", "Admin::Account"]).
    # Unknown names are reported and skipped instead of aborting the whole run.
    def run_named(names)
      names.each do |name|
        klass = name.safe_constantize
        unless klass.is_a?(Class) && klass < ActiveRecord::Base
          @output.puts "⚠️  Skipped #{name} — not an ActiveRecord model"
          next
        end

        run(klass)
      end
    end

    private

      def models
        Rails.application.eager_load!
        # All AR models, but skip STI subclasses (only keep base classes),
        # anonymous classes and generated HABTM join models.
        ActiveRecord::Base.descendants
          .reject(&:abstract_class?)
          .select { |m| m.base_class == m }
          .reject { |m| m.name.nil? || m.name.demodulize.start_with?("HABTM_") }
      end

      # Only files inside the application are ever written; models defined
      # in gems or engines (e.g. ActiveStorage::Blob) are skipped.
      def model_file(model)
        return if model.name.nil?

        file = Object.const_source_location(model.name)&.first
        file if file && app_file?(file)
      end

      def app_file?(file)
        root = "#{File.expand_path(Rails.root.to_s)}/"
        path = File.expand_path(file)
        path.start_with?(root) && !path.start_with?("#{root}vendor/")
      end

      def write_annotation(model, annotation)
        file = model_file(model)
        return unless file && File.exist?(file)

        content = File.read(file).dup

        # Verify the class definition exists before doing anything else.
        unless content.match?(/class\s+\w+/)
          @output.puts "⚠️  Skipped #{model.name} — class not found in file"
          return
        end

        # Skip writing if the annotation hasn't changed and there is no legacy block to clean up
        old_annotation = content[ANNOTATO_BLOCK]
        if old_annotation && old_annotation.strip == annotation.strip && !content.match?(LEGACY_BLOCK)
          return
        end

        if @check
          @outdated << model.name
          @output.puts "❌ Outdated annotation: #{model.name}"
          return
        end

        # Remove old Annotato blocks and legacy annotate-gem blocks
        content.gsub!(ANNOTATO_BLOCK, "")
        content.gsub!(LEGACY_BLOCK, "")
        content.rstrip!

        # Append the new annotation at the end of the file
        content += "\n\n#{annotation.rstrip}\n"
        write_file(file, content)

        @output.puts "✍️  Annotated #{model.name}"
      end

      # Writes via a temp file + rename so an interrupted run never leaves a truncated model file.
      def write_file(file, content)
        target = File.realpath(file)
        tmp    = "#{target}.annotato-#{Process.pid}.tmp"
        File.write(tmp, content)
        File.chmod(File.stat(target).mode, tmp)
        File.rename(tmp, target)
      ensure
        File.delete(tmp) if tmp && File.exist?(tmp)
      end
  end
end
