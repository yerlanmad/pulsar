class CallRecord < ApplicationRecord
  belongs_to :agent, optional: true
  belongs_to :queue_config, optional: true
  has_one :recording, dependent: :destroy

  enum :status, { queued: 0, answered: 1, completed: 2, abandoned: 3, failed: 4 }

  validates :uniqueid, uniqueness: true, allow_nil: true

  scope :recent, -> { order(started_at: :desc) }
  scope :today, -> { where(started_at: Time.current.beginning_of_day..) }

  def duration_display
    return "--" unless duration
    minutes = duration / 60
    seconds = duration % 60
    format("%<min>d:%<sec>02d", min: minutes, sec: seconds)
  end
end
