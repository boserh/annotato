# frozen_string_literal: true

require "spec_helper"
require "active_record"
require "annotato/annotation_builder"

# Runs the real formatters against an in-memory SQLite database, so non-PostgreSQL
# adapters are exercised end to end (no PG-only SQL, real adapter name, real metadata).
RSpec.describe "Annotato on SQLite" do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    conn = ActiveRecord::Base.connection
    conn.create_table :widgets do |t|
      t.string :name, null: false
      t.integer :quantity, default: 0
      t.json :settings, default: { "theme" => "dark" }
      t.datetime :seen_at, default: -> { "CURRENT_TIMESTAMP" }
      t.check_constraint "quantity >= 0", name: "chk_quantity_positive"
      t.index :name, unique: true
      t.index :quantity, where: "quantity > 0", name: "idx_positive_quantity"
    end
    conn.execute(<<~SQL)
      CREATE TRIGGER widgets_touch AFTER UPDATE ON widgets
      BEGIN UPDATE widgets SET seen_at = CURRENT_TIMESTAMP WHERE id = NEW.id; END
    SQL
  end

  after(:all) { ActiveRecord::Base.remove_connection }

  let(:model) { stub_const("Widget", Class.new(ActiveRecord::Base) { self.table_name = "widgets" }) }

  it "builds the full annotation" do
    annotation = Annotato::AnnotationBuilder.build(model)

    expect(annotation).to start_with("# == Annotato Schema Info\n# Table: widgets\n")
    expect(annotation).to match(/^#  id\s+:INTEGER not null, primary key$/)
    expect(annotation).to match(/^#  name\s+:varchar not null, unique$/)
    expect(annotation).to match(/^#  quantity\s+:INTEGER default\("0"\)$/)
    expect(annotation).to match(/^#  seen_at\s+:datetime(?:\(6\))? default\("?CURRENT_TIMESTAMP"?\)$/) # Rails < 7 reports it as a plain string
    expect(annotation).to match(/^#\s+"theme": "dark"$/)
    expect(annotation).to include("#  idx_positive_quantity (quantity)\n#    where (quantity > 0)")
    expect(annotation).to include("#  index_widgets_on_name (name) unique")
    expect(annotation).to include("# Triggers:\n#  widgets_touch")
    expect(annotation).to include("#  chk_quantity_positive\n#    (quantity >= 0)")
    expect(annotation).not_to include("Enums:")
  end
end
