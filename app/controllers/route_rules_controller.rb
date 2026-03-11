class RouteRulesController < ApplicationController
  before_action :set_route_rule, only: %i[show edit update destroy]

  def index
    authorize RouteRule
    @route_rules = RouteRule.includes(:queue_config).ordered
  end

  def show
    authorize @route_rule
  end

  def new
    authorize RouteRule
    @route_rule = RouteRule.new
    @queue_configs = QueueConfig.order(:name)
  end

  def create
    authorize RouteRule
    @route_rule = RouteRule.new(route_rule_params)

    if @route_rule.save
      redirect_to route_rules_path, notice: t("routes.created")
    else
      @queue_configs = QueueConfig.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @route_rule
    @queue_configs = QueueConfig.order(:name)
  end

  def update
    authorize @route_rule

    if @route_rule.update(route_rule_params)
      redirect_to route_rules_path, notice: t("routes.updated")
    else
      @queue_configs = QueueConfig.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @route_rule
    @route_rule.destroy
    redirect_to route_rules_path, notice: t("routes.deleted")
  end

  private

  def set_route_rule
    @route_rule = RouteRule.find(params[:id])
  end

  def route_rule_params
    params.require(:route_rule).permit(:name, :pattern, :queue_config_id, :position)
  end
end
