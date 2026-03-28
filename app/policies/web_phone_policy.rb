class WebPhonePolicy < ApplicationPolicy
  def credentials? = user.agent.present?
end
