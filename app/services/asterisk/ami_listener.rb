module Asterisk
  class AmiListener
    HOST = ENV.fetch("ASTERISK_AMI_HOST", "localhost")
    PORT = ENV.fetch("ASTERISK_AMI_PORT", "5038").to_i
    USERNAME = ENV.fetch("ASTERISK_AMI_USER", "admin")
    SECRET = ENV.fetch("ASTERISK_AMI_SECRET", "admin")

    def initialize
      @running = false
      @socket = nil
    end

    def start
      @running = true
      connect
      login
      listen
    rescue => e
      Rails.logger.error("AMI connection error: #{e.message}")
      retry_connection
    end

    def stop
      @running = false
      @socket&.close
    end

    private

    def connect
      @socket = TCPSocket.new(HOST, PORT)
      Rails.logger.info("AMI connected to #{HOST}:#{PORT}")
    end

    def login
      send_action("Login", { Username: USERNAME, Secret: SECRET })
    end

    def listen
      buffer = ""
      while @running && (line = @socket.gets)
        buffer += line
        if line.strip.empty?
          process_event(parse_event(buffer))
          buffer = ""
        end
      end
    end

    def send_action(action, params = {})
      message = "Action: #{action}\r\n"
      params.each { |k, v| message += "#{k}: #{v}\r\n" }
      message += "\r\n"
      @socket.write(message)
    end

    def parse_event(raw)
      event = {}
      raw.each_line do |line|
        next if line.strip.empty?
        key, value = line.strip.split(": ", 2)
        event[key] = value if key && value
      end
      event
    end

    def process_event(event)
      case event["Event"]
      when "AgentConnect"
        handle_agent_connect(event)
      when "AgentComplete"
        handle_agent_complete(event)
      when "QueueCallerAbandon"
        handle_abandon(event)
      when "PeerStatus"
        handle_peer_status(event)
      end
    end

    def handle_agent_connect(event)
      ActionCable.server.broadcast("call_status", {
        type: "agent_connect",
        queue: event["Queue"],
        agent: event["MemberName"],
        uniqueid: event["Uniqueid"]
      })
    end

    def handle_agent_complete(event)
      record_call(event, :completed)

      ActionCable.server.broadcast("call_status", {
        type: "agent_complete",
        queue: event["Queue"],
        agent: event["MemberName"],
        duration: event["TalkTime"]
      })
    end

    def handle_abandon(event)
      record_call(event, :abandoned)

      ActionCable.server.broadcast("call_status", {
        type: "abandoned",
        queue: event["Queue"],
        wait_time: event["HoldTime"]
      })
    end

    def handle_peer_status(event)
      peer = event["Peer"]
      status = event["PeerStatus"]

      agent = Agent.find_by(sip_account: peer)
      return unless agent

      new_status = status == "Reachable" ? :online : :offline
      agent.update(status: new_status)

      ActionCable.server.broadcast("agent_status", {
        type: "status_change",
        agent_id: agent.id,
        name: agent.name,
        status: new_status
      })
    end

    def record_call(event, status)
      call_record = CallRecord.create(
        uniqueid: event["Uniqueid"],
        caller_number: event["CallerIDNum"],
        destination_number: event["DestCallerIDNum"],
        queue_config: QueueConfig.find_by(name: event["Queue"]),
        agent: Agent.find_by(sip_account: event["MemberName"]),
        status: status,
        started_at: Time.current,
        duration: event["TalkTime"]&.to_i,
        wait_time: event["HoldTime"]&.to_i
      )

      attach_recording(call_record) if call_record.persisted? && status == :completed
    end

    def attach_recording(call_record)
      recordings_path = ENV.fetch("ASTERISK_RECORDINGS_PATH", "/rails/recordings")
      file_path = File.join(recordings_path, "#{call_record.uniqueid}.wav")

      return unless File.exist?(file_path)

      Recording.create(
        call_record: call_record,
        file_path: file_path,
        file_size: File.size(file_path),
        duration: call_record.duration
      )
    end

    def retry_connection
      return unless @running

      sleep 5
      start
    end
  end
end
