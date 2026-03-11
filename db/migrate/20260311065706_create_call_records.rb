class CreateCallRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :call_records do |t|
      t.string :uniqueid
      t.string :caller_number
      t.string :destination_number
      t.references :agent, foreign_key: true
      t.references :queue_config, foreign_key: true
      t.integer :status, default: 0, null: false

      t.index :uniqueid, unique: true
      t.index :started_at
      t.datetime :started_at
      t.datetime :answered_at
      t.datetime :ended_at
      t.integer :duration
      t.integer :wait_time

      t.timestamps
    end
  end
end
