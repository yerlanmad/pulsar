class CreateQueueConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :queue_configs do |t|
      t.string :name, null: false
      t.integer :strategy, default: 0, null: false
      t.integer :timeout, default: 30, null: false
      t.integer :timeout_action, default: 0, null: false
      t.integer :max_wait_time, default: 300, null: false

      t.index :name, unique: true

      t.timestamps
    end
  end
end
