require "test_helper"

class Asterisk::QueueManagerTest < ActiveSupport::TestCase
  test "queue_name_for normalizes queue name" do
    manager = Asterisk::QueueManager.new
    queue = queue_configs(:one) # "Support"

    name = manager.send(:queue_name_for, queue)
    assert_equal "support", name
  end

  test "sip_ext strips SIP prefix" do
    manager = Asterisk::QueueManager.new
    agent = agents(:one) # "SIP/1001"

    ext = manager.send(:sip_ext, agent)
    assert_equal "1001", ext
  end
end
