require "test_helper"

class QueueConfigTest < ActiveSupport::TestCase
  test "validates presence of name" do
    q = QueueConfig.new(strategy: :ringall, timeout: 30, max_wait_time: 300)
    assert_not q.valid?
    assert_includes q.errors[:name], "can't be blank"
  end

  test "validates uniqueness of name" do
    q = QueueConfig.new(name: queue_configs(:one).name, strategy: :ringall, timeout: 30, max_wait_time: 300)
    assert_not q.valid?
    assert_includes q.errors[:name], "has already been taken"
  end

  test "validates timeout is positive" do
    q = QueueConfig.new(name: "Test", strategy: :ringall, timeout: 0, max_wait_time: 300)
    assert_not q.valid?
    assert_includes q.errors[:timeout], "must be greater than 0"
  end

  test "strategy enum" do
    q = queue_configs(:one)
    assert q.ringall?
  end

  test "agents_online_count" do
    agents(:one).update!(status: :online)
    agents(:two).update!(status: :offline)
    assert_equal 1, queue_configs(:one).agents_online_count
  end
end
