class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents do |t|
      t.string :name, null: false
      t.string :sip_account, null: false
      t.integer :status, default: 0, null: false
      t.references :user, null: false, foreign_key: true

      t.index :sip_account, unique: true

      t.timestamps
    end
  end
end
