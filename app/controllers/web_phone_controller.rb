class WebPhoneController < ApplicationController
  before_action :require_agent

  def credentials
    ext = current_agent.sip_account.delete_prefix("SIP/").delete_prefix("PJSIP/")

    render json: {
      sip_user: ext,
      sip_password: "changeme#{ext}",
      sip_domain: asterisk_host,
      ws_url: "ws://#{asterisk_host}:8088/ws"
    }
  end

  private

  def require_agent
    head :not_found unless current_agent
  end

  def asterisk_host
    ENV.fetch("ASTERISK_WS_HOST", "89.167.93.11")
  end
end
