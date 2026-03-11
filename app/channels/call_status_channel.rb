class CallStatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "call_status"
  end
end
