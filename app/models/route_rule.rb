class RouteRule < ApplicationRecord
  belongs_to :queue_config

  validates :name, presence: true
  validates :pattern, presence: true

  scope :ordered, -> { order(:position) }

  after_commit :sync_extensions_config, on: %i[create update destroy]

  private

  def sync_extensions_config
    SyncAsteriskConfigJob.perform_later(:extensions)
  end
end
