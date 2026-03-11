class CallRecordsController < ApplicationController
  def index
    authorize CallRecord
    @call_records = CallRecord.includes(:agent, :queue_config, :recording).recent

    @call_records = @call_records.where(queue_config_id: params[:queue_id]) if params[:queue_id].present?
    @call_records = @call_records.where(agent_id: params[:agent_id]) if params[:agent_id].present?
    @call_records = @call_records.where(status: params[:status]) if params[:status].present?

    if params[:date_from].present?
      @call_records = @call_records.where(started_at: Date.parse(params[:date_from]).beginning_of_day..)
    end
    if params[:date_to].present?
      @call_records = @call_records.where(started_at: ..Date.parse(params[:date_to]).end_of_day)
    end

    @call_records = @call_records.limit(100)
    @queues = QueueConfig.order(:name)
    @agents = Agent.order(:name)
  end

  def show
    @call_record = CallRecord.includes(:recording, :agent, :queue_config).find(params[:id])
    authorize @call_record
  end
end
