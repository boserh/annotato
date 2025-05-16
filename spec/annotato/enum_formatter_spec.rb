# frozen_string_literal: true

require "spec_helper"
require "annotato/enum_formatter"

RSpec.describe Annotato::EnumFormatter do
  let(:model) { double("Model") }

  context "when model has no enums" do
    before { allow(model).to receive(:defined_enums).and_return({}) }

    it "returns empty array" do
      expect(described_class.format(model)).to eq([])
    end
  end

  context "when enums have string values equal to keys" do
    let(:enums) do
      {
        "delivery_type" => {
          "truck_delivery" => "truck_delivery",
          "ship_delivery" => "ship_delivery"
        }
      }
    end

    before { allow(model).to receive(:defined_enums).and_return(enums) }

    it "formats enums without values" do
      result = described_class.format(model)
      expect(result).to include(<<~ENUM.strip)
        #  delivery_type: {
        #    truck_delivery,
        #    ship_delivery
        #  }
      ENUM
    end
  end

  context "when enums have different values" do
    let(:enums) do
      {
        "status" => {
          "draft" => "0",
          "published" => "1",
          "archived" => "2"
        }
      }
    end

    before { allow(model).to receive(:defined_enums).and_return(enums) }

    it "formats enums with values" do
      result = described_class.format(model)
      expect(result).to include(<<~ENUM.strip)
        #  status: {
        #    draft (0),
        #    published (1),
        #    archived (2)
        #  }
      ENUM
    end
  end
end
