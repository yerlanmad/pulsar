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
    @agent.update!(status: params[:status])
    redirect_back fallback_location: agents_path, notice: t("agents.status_changed", status: @agent.status)
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(:name, :sip_account, :status, :user_id)
  end
end
