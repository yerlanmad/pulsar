class CreateRecordings < ActiveRecord::Migration[8.1]
  def change
    create_table :recordings do |t|
      t.references :call_record, null: false, foreign_key: true
      t.string :file_path
      t.integer :file_size
      t.integer :duration

      t.timestamps
    end
  end
end
