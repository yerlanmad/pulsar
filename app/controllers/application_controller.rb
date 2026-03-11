class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :current_agent

  def current_user
    Current.user
  end

  def current_agent
    @current_agent ||= Current.user&.agent
  end

  private

  def user_not_authorized
    flash[:alert] = t("common.not_authorized")
    redirect_back(fallback_location: root_path)
  end
end
