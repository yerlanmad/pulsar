class DashboardController < ApplicationController
  def show
    authorize :dashboard, :show?

    @agents_online = Agent.online.count
    @agents_total = Agent.count
    @active_calls = CallRecord.where(status: %i[queued answered]).count
    @calls_today = CallRecord.today.count
    @abandoned_today = CallRecord.today.abandoned.count
    @queues = QueueConfig.includes(:agents).all

    @avg_wait_time = CallRecord.today.where.not(wait_time: nil).average(:wait_time)&.round || 0
    @avg_duration = CallRecord.today.completed.where.not(duration: nil).average(:duration)&.round || 0
  end
end
