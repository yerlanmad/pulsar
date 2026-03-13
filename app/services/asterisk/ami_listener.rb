module Asterisk
  class AmiListener
    HOST = ENV.fetch("ASTERISK_AMI_HOST", "localhost")
    PORT = ENV.fetch("ASTERISK_AMI_PORT", "5038").to_i
    USERNAME = ENV.fetch("ASTERISK_AMI_USER", "admin")

    def self.secret
      Rails.application.credentials.dig(:asterisk, :ami_secret) || ENV.fetch("ASTERISK_AMI_SECRET", "admin")
    end

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
      send_action("Login", { Username: USERNAME, Secret: self.class.secret })
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
      when "QueueCallerJoin"
        handle_caller_join(event)
      when "AgentConnect"
        handle_agent_connect(event)
      when "AgentComplete"
        handle_agent_complete(event)
      when "QueueCallerAbandon"
        handle_abandon(event)
      when "PeerStatus"
        handle_peer_status(event)
      when "DeviceStateChange"
        handle_device_state(event)
      when "QueueMemberPause"
        handle_member_pause(event)
      when "AgentRingNoAnswer"
        handle_ring_no_answer(event)
      when "DialBegin"
        handle_dial_begin(event)
      when "DialEnd"
        handle_dial_end(event)
      when "Hangup"
        handle_hangup(event)
      end
    rescue => e
      Rails.logger.error("AMI event processing error: #{e.message} — Event: #{event['Event']}")
    end

    def handle_caller_join(event)
      call_record = CallRecord.find_or_create_by(uniqueid: event["Uniqueid"]) do |r|
        r.caller_number = event["CallerIDNum"]
        r.destination_number = event["ConnectedLineNum"]
        r.queue_config = find_queue(event["Queue"])
        r.status = :queued
        r.started_at = Time.current
      end

      broadcast_call_event("caller_join", event)
      broadcast_dashboard
    end

    def handle_agent_connect(event)
      call_record = CallRecord.find_or_initialize_by(uniqueid: event["Uniqueid"])
      call_record.update(
        agent: find_agent(event["MemberName"]),
        queue_config: find_queue(event["Queue"]),
        caller_number: event["CallerIDNum"] || call_record.caller_number,
        status: :answered,
        answered_at: Time.current,
        wait_time: event["HoldTime"]&.to_i,
        started_at: call_record.started_at || Time.current
      )

      agent = find_agent(event["MemberName"])
      agent&.update_column(:status, Agent.statuses[:busy])

      broadcast_call_event("agent_connect", event)
      broadcast_dashboard
    end

    def handle_agent_complete(event)
      call_record = CallRecord.find_or_initialize_by(uniqueid: event["Uniqueid"])
      call_record.update(
        agent: find_agent(event["MemberName"]),
        queue_config: find_queue(event["Queue"]),
        caller_number: event["CallerIDNum"] || call_record.caller_number,
        destination_number: event["ConnectedLineNum"] || call_record.destination_number,
        status: :completed,
        ended_at: Time.current,
        duration: event["TalkTime"]&.to_i,
        wait_time: event["HoldTime"]&.to_i,
        started_at: call_record.started_at || Time.current
      )

      agent = find_agent(event["MemberName"])
      agent&.update_column(:status, Agent.statuses[:online])

      attach_recording(call_record) if call_record.persisted?

      broadcast_call_event("agent_complete", event)
      broadcast_dashboard
    end

    def handle_abandon(event)
      call_record = CallRecord.find_or_initialize_by(uniqueid: event["Uniqueid"])
      call_record.update(
        queue_config: find_queue(event["Queue"]),
        caller_number: event["CallerIDNum"] || call_record.caller_number,
        status: :abandoned,
        ended_at: Time.current,
        wait_time: event["HoldTime"]&.to_i,
        started_at: call_record.started_at || Time.current
      )

      broadcast_call_event("abandoned", event)
      broadcast_dashboard
    end

    def handle_peer_status(event)
      peer = event["Peer"]&.delete_prefix("PJSIP/")
      status = event["PeerStatus"]
      return unless peer

      agent = Agent.find_by(sip_account: peer)
      return unless agent

      new_status = case status
      when "Reachable" then :online
      when "Unreachable", "Unregistered" then :offline
      else return
      end

      agent.update_column(:status, Agent.statuses[new_status])

      ActionCable.server.broadcast("agent_status", {
        type: "status_change",
        agent_id: agent.id,
        name: agent.name,
        status: new_status
      })

      broadcast_dashboard
    end

    def handle_device_state(event)
      device = event["Device"]&.delete_prefix("PJSIP/")
      state = event["State"]
      return unless device

      agent = Agent.find_by(sip_account: device)
      return unless agent

      new_status = case state
      when "NOT_INUSE" then :online
      when "INUSE", "RINGING", "RINGINUSE" then :busy
      when "UNAVAILABLE", "INVALID" then :offline
      else return
      end

      agent.update_column(:status, Agent.statuses[new_status])

      ActionCable.server.broadcast("agent_status", {
        type: "status_change",
        agent_id: agent.id,
        name: agent.name,
        status: new_status
      })

      broadcast_dashboard
    end

    def handle_member_pause(event)
      interface = event["MemberName"]&.delete_prefix("PJSIP/")
      paused = event["Paused"] == "1"
      return unless interface

      agent = Agent.find_by(sip_account: interface)
      return unless agent

      new_status = paused ? :on_break : :online
      agent.update_column(:status, Agent.statuses[new_status])

      ActionCable.server.broadcast("agent_status", {
        type: "status_change",
        agent_id: agent.id,
        name: agent.name,
        status: new_status
      })

      broadcast_dashboard
    end

    def handle_hangup(event)
      uniqueid = event["Uniqueid"]
      call_record = CallRecord.find_by(uniqueid: uniqueid)
      return unless call_record
      return if call_record.completed? || call_record.failed? || call_record.abandoned?

      duration = if call_record.answered_at
                   (Time.current - call_record.answered_at).to_i
                 end

      call_record.update(
        status: :completed,
        ended_at: Time.current,
        duration: duration
      )

      attach_recording(call_record)
      broadcast_dashboard
    end

    def handle_dial_begin(event)
      # Only track outbound calls (from-internal context)
      context = event["DestContext"] || event["Context"]
      return unless context == "from-internal" || event["DialString"]&.include?("@")

      uniqueid = event["Uniqueid"]
      caller_ext = event["CallerIDNum"]
      dest_num = event["DestCallerIDNum"] || event["DialString"]&.gsub(/.*\//, "")&.gsub(/@.*/, "")

      CallRecord.find_or_create_by(uniqueid: uniqueid) do |r|
        r.caller_number = caller_ext
        r.destination_number = dest_num
        r.agent = Agent.find_by(sip_account: caller_ext)
        r.status = :queued
        r.started_at = Time.current
      end

      broadcast_dashboard
    end

    def handle_dial_end(event)
      uniqueid = event["Uniqueid"]
      dial_status = event["DialStatus"]

      call_record = CallRecord.find_by(uniqueid: uniqueid)
      return unless call_record

      case dial_status
      when "ANSWER"
        call_record.update(
          status: :answered,
          answered_at: Time.current,
          destination_number: event["DestCallerIDNum"] || call_record.destination_number
        )
      when "NOANSWER", "BUSY", "CONGESTION", "CHANUNAVAIL"
        call_record.update(
          status: :failed,
          ended_at: Time.current
        )
        attach_recording(call_record)
      when "CANCEL"
        call_record.update(
          status: :abandoned,
          ended_at: Time.current
        )
      end

      broadcast_dashboard
    end

    def handle_ring_no_answer(event)
      agent = find_agent(event["MemberName"])
      return unless agent

      # If agent didn't answer, check if they're still reachable
      # If unreachable, mark offline — Asterisk already re-routes the call
      if event["RingTime"]&.to_i&.>= agent.queue_configs.minimum(:timeout).to_i
        Rails.logger.warn("Agent #{agent.name} (#{agent.sip_account}) ring timeout — possible disconnect")
      end

      broadcast_dashboard
    end

    def find_agent(member_name)
      ext = member_name&.delete_prefix("PJSIP/")&.delete_prefix("SIP/")
      Agent.find_by(sip_account: ext)
    end

    def find_queue(queue_name)
      return nil unless queue_name
      QueueConfig.find_by("LOWER(REPLACE(name, ' ', '_')) = ?", queue_name.downcase)
    end

    def attach_recording(call_record)
      recordings_path = ENV.fetch("ASTERISK_RECORDINGS_PATH", "/rails/recordings")
      file_path = File.join(recordings_path, "#{call_record.uniqueid}.wav")

      return unless File.exist?(file_path)
      return if call_record.recording.present?

      Recording.create(
        call_record: call_record,
        file_path: file_path,
        file_size: File.size(file_path),
        duration: call_record.duration
      )
    end

    def broadcast_call_event(type, event)
      ActionCable.server.broadcast("call_status", {
        type: type,
        queue: event["Queue"],
        agent: event["MemberName"],
        uniqueid: event["Uniqueid"],
        caller: event["CallerIDNum"]
      })
    end

    def broadcast_dashboard
      BroadcastDashboardJob.perform_later
    end

    def retry_connection
      return unless @running

      sleep 5
      start
    end
  end
end
