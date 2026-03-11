class Agent < ApplicationRecord
  belongs_to :user
  has_many :queue_memberships, dependent: :destroy
  has_many :queue_configs, through: :queue_memberships
  has_many :call_records, dependent: :nullify

  enum :status, { offline: 0, online: 1, busy: 2, on_break: 3 }

  validates :name, presence: true
  validates :sip_account, presence: true, uniqueness: true

  scope :available, -> { where(status: :online) }

  after_commit :sync_pjsip_config, on: %i[create update destroy]
  after_commit :broadcast_dashboard, on: %i[create update destroy]

  private

  def sync_pjsip_config
    SyncAsteriskConfigJob.perform_later(:pjsip)
  end

  def broadcast_dashboard
    BroadcastDashboardJob.perform_later
  end
end
