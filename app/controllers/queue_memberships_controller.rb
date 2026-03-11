class QueueMembershipsController < ApplicationController
  before_action :set_queue_config

  def create
    authorize @queue_config, :update?

    membership = @queue_config.queue_memberships.build(queue_membership_params)

    if membership.save
      redirect_to @queue_config, notice: t("queues.agent_added")
    else
      redirect_to @queue_config, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @queue_config, :update?

    membership = @queue_config.queue_memberships.find(params[:id])
    membership.destroy
    redirect_to @queue_config, notice: t("queues.agent_removed")
  end

  private

  def set_queue_config
    @queue_config = QueueConfig.find(params[:queue_config_id])
  end

  def queue_membership_params
    params.require(:queue_membership).permit(:agent_id, :priority)
  end
end
