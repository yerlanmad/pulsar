class QueueStatsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "queue_stats"
  end
end
