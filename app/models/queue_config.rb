class QueueConfig < ApplicationRecord
  has_many :queue_memberships, dependent: :destroy
  has_many :agents, through: :queue_memberships
  has_many :route_rules, dependent: :destroy
  has_many :call_records, dependent: :nullify

  enum :strategy, { ringall: 0, leastrecent: 1, fewestcalls: 2, random: 3, rrmemory: 4 }
  enum :timeout_action, { hangup: 0, voicemail: 1, redirect: 2 }

  validates :name, presence: true, uniqueness: true
  validates :timeout, numericality: { greater_than: 0 }
  validates :max_wait_time, numericality: { greater_than: 0 }

  def agents_online_count
    agents.where(status: :online).count
  end

  after_commit :sync_queue_config, on: %i[create update destroy]

  private

  def sync_queue_config
    SyncAsteriskConfigJob.perform_later(:queues)
  end
end
