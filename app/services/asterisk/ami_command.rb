module Asterisk
  class AmiCommand
    HOST = ENV.fetch("ASTERISK_AMI_HOST", "localhost")
    PORT = ENV.fetch("ASTERISK_AMI_PORT", "5038").to_i
    USERNAME = ENV.fetch("ASTERISK_AMI_USER", "admin")
    TIMEOUT = 5

    def self.secret
      Rails.application.credentials.dig(:asterisk, :ami_secret) || ENV.fetch("ASTERISK_AMI_SECRET", "admin")
    end

    def reload(module_name)
      execute do |socket|
        case module_name.to_s
        when "pjsip"
          send_and_read(socket, "Command", Command: "pjsip reload")
        when "queues"
          send_and_read(socket, "QueueReload")
        when "dialplan"
          send_and_read(socket, "Command", Command: "dialplan reload")
        when "all"
          send_and_read(socket, "Command", Command: "core reload")
        end
      end
    end

    def queue_add(queue_name, interface, penalty: 0)
      execute do |socket|
        send_and_read(socket, "QueueAdd",
          Queue: queue_name,
          Interface: interface,
          Penalty: penalty,
          Paused: "false"
        )
      end
    end

    def queue_remove(queue_name, interface)
      execute do |socket|
        send_and_read(socket, "QueueRemove",
          Queue: queue_name,
          Interface: interface
        )
      end
    end

    def queue_pause(queue_name, interface, paused: true)
      execute do |socket|
        send_and_read(socket, "QueuePause",
          Queue: queue_name,
          Interface: interface,
          Paused: paused ? "true" : "false"
        )
      end
    end

    private

    def execute
      socket = TCPSocket.new(HOST, PORT)
      socket.gets # read AMI banner

      login_response = send_and_read(socket, "Login", Username: USERNAME, Secret: self.class.secret)
      unless login_response.include?("Success")
        Rails.logger.error("AMI login failed: #{login_response}")
        return false
      end

      result = yield(socket)

      send_action(socket, "Logoff")
      socket.close
      result
    rescue => e
      Rails.logger.error("AMI command error: #{e.message}")
      false
    ensure
      socket&.close rescue nil
    end

    def send_and_read(socket, action, params = {})
      send_action(socket, action, params)
      read_response(socket)
    end

    def send_action(socket, action, params = {})
      message = "Action: #{action}\r\n"
      params.each { |k, v| message += "#{k}: #{v}\r\n" }
      message += "\r\n"
      socket.write(message)
    end

    def read_response(socket)
      response = ""
      while (line = socket.gets)
        response += line
        break if line.strip.empty?
      end
      response
    end
  end
end
