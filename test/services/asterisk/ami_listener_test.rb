require "test_helper"

class Asterisk::AmiListenerTest < ActiveSupport::TestCase
  setup do
    @listener = Asterisk::AmiListener.new
  end

  test "handle_peer_status sets agent online when Reachable" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:offline])

    event = {
      "Event" => "PeerStatus",
      "Peer" => "PJSIP/1001",
      "PeerStatus" => "Reachable"
    }

    @listener.send(:process_event, event)

    assert_equal "online", agent.reload.status
  end

  test "handle_peer_status sets agent offline when Unreachable" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:online])

    event = {
      "Event" => "PeerStatus",
      "Peer" => "PJSIP/1001",
      "PeerStatus" => "Unreachable"
    }

    @listener.send(:process_event, event)

    assert_equal "offline", agent.reload.status
  end

  test "handle_peer_status ignores unknown peers" do
    event = {
      "Event" => "PeerStatus",
      "Peer" => "PJSIP/9999",
      "PeerStatus" => "Reachable"
    }

    assert_nothing_raised { @listener.send(:process_event, event) }
  end

  test "handle_device_state sets agent busy when INUSE" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:online])

    event = {
      "Event" => "DeviceStateChange",
      "Device" => "PJSIP/1001",
      "State" => "INUSE"
    }

    @listener.send(:process_event, event)

    assert_equal "busy", agent.reload.status
  end

  test "handle_device_state sets agent online when NOT_INUSE" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:busy])

    event = {
      "Event" => "DeviceStateChange",
      "Device" => "PJSIP/1001",
      "State" => "NOT_INUSE"
    }

    @listener.send(:process_event, event)

    assert_equal "online", agent.reload.status
  end

  test "handle_member_pause sets agent on_break when paused" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:online])

    event = {
      "Event" => "QueueMemberPause",
      "MemberName" => "PJSIP/1001",
      "Queue" => "support",
      "Paused" => "1"
    }

    @listener.send(:process_event, event)

    assert_equal "on_break", agent.reload.status
  end

  test "handle_member_pause sets agent online when unpaused" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:on_break])

    event = {
      "Event" => "QueueMemberPause",
      "MemberName" => "PJSIP/1001",
      "Queue" => "support",
      "Paused" => "0"
    }

    @listener.send(:process_event, event)

    assert_equal "online", agent.reload.status
  end

  test "handle_caller_join creates queued call record" do
    assert_difference "CallRecord.count" do
      event = {
        "Event" => "QueueCallerJoin",
        "Uniqueid" => "test-join-001",
        "CallerIDNum" => "+18005551234",
        "ConnectedLineNum" => "+18005559999",
        "Queue" => "support"
      }

      @listener.send(:process_event, event)
    end

    record = CallRecord.find_by(uniqueid: "test-join-001")
    assert_equal "queued", record.status
    assert_equal "+18005551234", record.caller_number
    assert_equal queue_configs(:one), record.queue_config
  end

  test "handle_agent_connect updates call record to answered" do
    CallRecord.create!(uniqueid: "test-connect-001", caller_number: "+18005551234", status: :queued, started_at: 1.minute.ago)

    event = {
      "Event" => "AgentConnect",
      "Uniqueid" => "test-connect-001",
      "CallerIDNum" => "+18005551234",
      "MemberName" => "PJSIP/1001",
      "Queue" => "support",
      "HoldTime" => "15"
    }

    @listener.send(:process_event, event)

    record = CallRecord.find_by(uniqueid: "test-connect-001")
    assert_equal "answered", record.status
    assert_equal agents(:one), record.agent
    assert_equal 15, record.wait_time
  end

  test "handle_agent_connect sets agent to busy" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:online])

    event = {
      "Event" => "AgentConnect",
      "Uniqueid" => "test-busy-001",
      "CallerIDNum" => "+18005551234",
      "MemberName" => "PJSIP/1001",
      "Queue" => "support",
      "HoldTime" => "5"
    }

    @listener.send(:process_event, event)

    assert_equal "busy", agent.reload.status
  end

  test "handle_agent_complete updates call record to completed" do
    CallRecord.create!(uniqueid: "test-complete-001", caller_number: "+18005551234", status: :answered, started_at: 3.minutes.ago, answered_at: 2.minutes.ago)

    event = {
      "Event" => "AgentComplete",
      "Uniqueid" => "test-complete-001",
      "CallerIDNum" => "+18005551234",
      "DestCallerIDNum" => "+18005559999",
      "MemberName" => "PJSIP/1001",
      "Queue" => "support",
      "TalkTime" => "120",
      "HoldTime" => "10"
    }

    @listener.send(:process_event, event)

    record = CallRecord.find_by(uniqueid: "test-complete-001")
    assert_equal "completed", record.status
    assert_equal 120, record.duration
    assert_equal 10, record.wait_time
    assert_not_nil record.ended_at
  end

  test "handle_agent_complete sets agent back to online" do
    agent = agents(:one)
    agent.update_column(:status, Agent.statuses[:busy])

    event = {
      "Event" => "AgentComplete",
      "Uniqueid" => "test-online-001",
      "MemberName" => "PJSIP/1001",
      "Queue" => "support",
      "TalkTime" => "60",
      "HoldTime" => "5"
    }

    @listener.send(:process_event, event)

    assert_equal "online", agent.reload.status
  end

  test "handle_abandon creates abandoned call record" do
    assert_difference "CallRecord.count" do
      event = {
        "Event" => "QueueCallerAbandon",
        "Uniqueid" => "test-abandon-001",
        "CallerIDNum" => "+18005551234",
        "Queue" => "support",
        "HoldTime" => "45"
      }

      @listener.send(:process_event, event)
    end

    record = CallRecord.find_by(uniqueid: "test-abandon-001")
    assert_equal "abandoned", record.status
    assert_equal 45, record.wait_time
  end

  test "handle_dial_begin creates call record for outbound call" do
    assert_difference "CallRecord.count" do
      event = {
        "Event" => "DialBegin",
        "Uniqueid" => "test-dial-001",
        "CallerIDNum" => "1001",
        "DestCallerIDNum" => "+971542572940",
        "DialString" => "+971542572940@twilio-trunk",
        "Context" => "from-internal"
      }

      @listener.send(:process_event, event)
    end

    record = CallRecord.find_by(uniqueid: "test-dial-001")
    assert_equal "queued", record.status
    assert_equal "1001", record.caller_number
    assert_equal "+971542572940", record.destination_number
    assert_equal agents(:one), record.agent
  end

  test "handle_dial_end marks call as answered" do
    CallRecord.create!(uniqueid: "test-dialend-001", caller_number: "1001", status: :queued, started_at: 1.minute.ago)

    event = {
      "Event" => "DialEnd",
      "Uniqueid" => "test-dialend-001",
      "DialStatus" => "ANSWER",
      "DestCallerIDNum" => "+971542572940"
    }

    @listener.send(:process_event, event)

    record = CallRecord.find_by(uniqueid: "test-dialend-001")
    assert_equal "answered", record.status
    assert_not_nil record.answered_at
  end

  test "handle_dial_end marks call as failed on NOANSWER" do
    CallRecord.create!(uniqueid: "test-noanswer-001", caller_number: "1001", status: :queued, started_at: 1.minute.ago)

    event = {
      "Event" => "DialEnd",
      "Uniqueid" => "test-noanswer-001",
      "DialStatus" => "NOANSWER"
    }

    @listener.send(:process_event, event)

    record = CallRecord.find_by(uniqueid: "test-noanswer-001")
    assert_equal "failed", record.status
  end

  test "handle_hangup completes answered call with duration" do
    started = 3.minutes.ago
    answered = 2.minutes.ago
    CallRecord.create!(uniqueid: "test-hangup-001", caller_number: "1001", status: :answered, started_at: started, answered_at: answered)

    event = {
      "Event" => "Hangup",
      "Uniqueid" => "test-hangup-001"
    }

    @listener.send(:process_event, event)

    record = CallRecord.find_by(uniqueid: "test-hangup-001")
    assert_equal "completed", record.status
    assert_not_nil record.ended_at
    assert_operator record.duration, :>, 0
  end

  test "handle_hangup does not overwrite already completed call" do
    CallRecord.create!(uniqueid: "test-hangup-done", caller_number: "1001", status: :completed, started_at: 5.minutes.ago, ended_at: 1.minute.ago, duration: 120)

    event = {
      "Event" => "Hangup",
      "Uniqueid" => "test-hangup-done"
    }

    @listener.send(:process_event, event)

    record = CallRecord.find_by(uniqueid: "test-hangup-done")
    assert_equal "completed", record.status
    assert_equal 120, record.duration
  end

  test "find_queue matches queue by normalized name" do
    queue = @listener.send(:find_queue, "support")
    assert_equal queue_configs(:one), queue
  end

  test "find_agent strips PJSIP prefix" do
    agent = agents(:one)
    found = @listener.send(:find_agent, "PJSIP/#{agent.sip_account}")
    assert_equal agent, found
  end

  test "parse_event converts raw AMI text to hash" do
    raw = "Event: PeerStatus\r\nPeer: PJSIP/1001\r\nPeerStatus: Reachable\r\n\r\n"
    event = @listener.send(:parse_event, raw)

    assert_equal "PeerStatus", event["Event"]
    assert_equal "PJSIP/1001", event["Peer"]
    assert_equal "Reachable", event["PeerStatus"]
  end
end
