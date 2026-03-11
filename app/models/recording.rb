class Recording < ApplicationRecord
  belongs_to :call_record

  scope :recent, -> { order(created_at: :desc) }

  delegate :caller_number, :destination_number, :agent, :queue_config, to: :call_record

  def duration_display
    return "--" unless duration
    minutes = duration / 60
    seconds = duration % 60
    format("%<min>d:%<sec>02d", min: minutes, sec: seconds)
  end
end
