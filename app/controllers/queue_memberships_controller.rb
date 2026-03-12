class QueueMembershipsController < ApplicationController
  before_action :set_queue_config

  def create
    authorize @queue_config, :update?

    membership = @queue_config.queue_memberships.build(queue_membership_params)

    if membership.save
      sync_add_member(membership)
      redirect_to @queue_config, notice: t("queues.agent_added")
    else
      redirect_to @queue_config, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @queue_config, :update?

    membership = @queue_config.queue_memberships.find(params[:id])
    agent = membership.agent
    membership.destroy
    sync_remove_member(@queue_config, agent)
    redirect_to @queue_config, notice: t("queues.agent_removed")
  end

  private

  def set_queue_config
    @queue_config = QueueConfig.find(params[:queue_config_id])
  end

  def queue_membership_params
    params.require(:queue_membership).permit(:agent_id, :priority)
  end

  def sync_add_member(membership)
    Asterisk::QueueManager.new.add_member(membership.queue_config, membership.agent)
  rescue => e
    Rails.logger.error("Failed to add queue member via AMI: #{e.message}")
  end

  def sync_remove_member(queue_config, agent)
    Asterisk::QueueManager.new.remove_member(queue_config, agent)
  rescue => e
    Rails.logger.error("Failed to remove queue member via AMI: #{e.message}")
  end
end
