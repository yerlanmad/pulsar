class AgentStatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_status"
  end
end
