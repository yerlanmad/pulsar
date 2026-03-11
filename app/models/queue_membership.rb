class QueueMembership < ApplicationRecord
  belongs_to :agent
  belongs_to :queue_config

  validates :agent_id, uniqueness: { scope: :queue_config_id }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }

  after_commit :sync_queue_config, on: %i[create destroy]

  private

  def sync_queue_config
    SyncAsteriskConfigJob.perform_later(:queues)
  end
end
