class CreateRouteRules < ActiveRecord::Migration[8.1]
  def change
    create_table :route_rules do |t|
      t.string :name, null: false
      t.string :pattern, null: false
      t.references :queue_config, null: false, foreign_key: true
      t.integer :position, default: 0, null: false

      t.index :position

      t.timestamps
    end
  end
end
