class QueueConfigsController < ApplicationController
  before_action :set_queue_config, only: %i[show edit update destroy]

  def index
    authorize QueueConfig
    @queue_configs = QueueConfig.includes(:agents).order(:name)
  end

  def show
    authorize @queue_config
    @available_agents = Agent.where.not(id: @queue_config.agent_ids).order(:name)
  end

  def new
    authorize QueueConfig
    @queue_config = QueueConfig.new
  end

  def create
    authorize QueueConfig
    @queue_config = QueueConfig.new(queue_config_params)

    if @queue_config.save
      redirect_to @queue_config, notice: t("queues.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @queue_config
  end

  def update
    authorize @queue_config

    if @queue_config.update(queue_config_params)
      redirect_to @queue_config, notice: t("queues.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @queue_config
    @queue_config.destroy
    redirect_to queue_configs_path, notice: t("queues.deleted")
  end

  private

  def set_queue_config
    @queue_config = QueueConfig.find(params[:id])
  end

  def queue_config_params
    params.require(:queue_config).permit(:name, :strategy, :timeout, :timeout_action, :max_wait_time)
  end
end
