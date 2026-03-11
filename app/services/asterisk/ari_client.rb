module Asterisk
  class AriClient
    BASE_URL = ENV.fetch("ASTERISK_ARI_URL", "http://localhost:8088/ari")
    USERNAME = ENV.fetch("ASTERISK_ARI_USER", "asterisk")

    def self.password
      Rails.application.credentials.dig(:asterisk, :ari_pass) || ENV.fetch("ASTERISK_ARI_PASS", "asterisk")
    end

    def initialize
      @connection = Faraday.new(url: BASE_URL) do |conn|
        conn.request :json
        conn.response :json
        conn.request :authorization, :basic, USERNAME, self.class.password
        conn.adapter Faraday.default_adapter
      end
    end

    def channels
      get("/channels")
    end

    def channel(channel_id)
      get("/channels/#{channel_id}")
    end

    def originate(endpoint:, extension:, context: "default")
      post("/channels", {
        endpoint: endpoint,
        extension: extension,
        context: context
      })
    end

    def hangup(channel_id)
      delete("/channels/#{channel_id}")
    end

    def bridges
      get("/bridges")
    end

    def endpoints
      get("/endpoints")
    end

    def asterisk_info
      get("/asterisk/info")
    end

    private

    def get(path)
      response = @connection.get(path)
      handle_response(response)
    end

    def post(path, body = {})
      response = @connection.post(path, body)
      handle_response(response)
    end

    def delete(path)
      response = @connection.delete(path)
      handle_response(response)
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      else
        Rails.logger.error("ARI error: #{response.status} - #{response.body}")
        nil
      end
    end
  end
end
