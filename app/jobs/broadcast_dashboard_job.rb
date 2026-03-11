class BroadcastDashboardJob < ApplicationJob
  queue_as :default

  def perform
    agents_online = Agent.online.count
    agents_total = Agent.count
    active_calls = CallRecord.where(status: %i[queued answered]).count
    calls_today = CallRecord.today.count
    abandoned_today = CallRecord.today.abandoned.count
    avg_wait_time = CallRecord.today.where.not(wait_time: nil).average(:wait_time)&.round || 0
    avg_duration = CallRecord.today.completed.where.not(duration: nil).average(:duration)&.round || 0

    Turbo::StreamsChannel.broadcast_replace_to(
      "dashboard_stats",
      target: "dashboard-stats",
      partial: "dashboard/stats",
      locals: {
        agents_online: agents_online,
        agents_total: agents_total,
        active_calls: active_calls,
        calls_today: calls_today,
        abandoned_today: abandoned_today,
        avg_wait_time: avg_wait_time,
        avg_duration: avg_duration
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "dashboard_stats",
      target: "dashboard-agents",
      partial: "dashboard/agent_table",
      locals: { agents: Agent.includes(:queue_configs).order(:name) }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "dashboard_stats",
      target: "dashboard-queues",
      partial: "dashboard/queue_table",
      locals: { queues: QueueConfig.includes(:agents).all }
    )
  end
end
