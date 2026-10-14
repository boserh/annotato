# frozen_string_literal: true

require "spec_helper"
require "annotato/auto_annotate"

RSpec.describe Annotato::AutoAnnotate do
  describe ".enabled?" do
    it "is enabled only in development" do
      expect(described_class.enabled?("development", {})).to be true
      expect(described_class.enabled?("production", {})).to be false
      expect(described_class.enabled?("test", {})).to be false
    end

    it "can be turned off with ANNOTATO_SKIP" do
      %w[1 true YES].each do |value|
        expect(described_class.enabled?("development", "ANNOTATO_SKIP" => value)).to be false
      end
      expect(described_class.enabled?("development", "ANNOTATO_SKIP" => "0")).to be true
    end
  end

  describe ".task_names" do
    it "selects migrate and rollback tasks, including per-database variants" do
      all = %w[
        db:migrate db:rollback db:migrate:primary db:rollback:animals db:migrate:up db:migrate:redo
        db:migrate:status db:migrate:status:primary db:seed db:schema:load annotato:models
      ]

      expect(described_class.task_names(all)).to eq(
        %w[db:migrate db:rollback db:migrate:primary db:rollback:animals db:migrate:up db:migrate:redo]
      )
    end
  end
end
