class AgentsController < ApplicationController
  before_action :set_agent, only: %i[show edit update destroy update_status]

  def index
    authorize Agent
    @agents = Agent.includes(:user, :queue_configs).order(:name)
  end

  def show
    authorize @agent
  end

  def new
    authorize Agent
    @agent = Agent.new
  end

  def create
    authorize Agent
    @agent = Agent.new(agent_params)

    if @agent.save
      redirect_to @agent, notice: t("agents.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @agent
  end

  def update
    authorize @agent

    if @agent.update(agent_params)
      redirect_to @agent, notice: t("agents.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @agent
    @agent.destroy
    redirect_to agents_path, notice: t("agents.deleted")
  end

  def update_status
    authorize @agent
    new_status = params[:status]

    @agent.update!(status: new_status)
    sync_agent_queue_status(@agent, new_status)

    redirect_back fallback_location: agents_path, notice: t("agents.status_changed", status: @agent.status)
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(:name, :sip_account, :status, :user_id)
  end

  def sync_agent_queue_status(agent, status)
    manager = Asterisk::QueueManager.new

    agent.queue_configs.each do |queue|
      case status.to_s
      when "on_break"
        manager.pause_member(queue, agent, paused: true)
      when "online"
        manager.pause_member(queue, agent, paused: false)
      end
    end
  rescue => e
    Rails.logger.error("Failed to sync agent queue status: #{e.message}")
  end
end
