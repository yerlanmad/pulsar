# frozen_string_literal: true

class AgentPolicy < ApplicationPolicy
  def update_status?
    user.admin? || user.supervisor? || (user.agent? && record.user_id == user.id)
  end
end
