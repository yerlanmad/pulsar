class CreateQueueMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :queue_memberships do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :queue_config, null: false, foreign_key: true
      t.integer :priority, default: 0, null: false

      t.index %i[agent_id queue_config_id], unique: true

      t.timestamps
    end
  end
end
