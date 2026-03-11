require "test_helper"

class AgentTest < ActiveSupport::TestCase
  test "validates presence of name" do
    agent = Agent.new(sip_account: "SIP/9999", user: users(:one))
    assert_not agent.valid?
    assert_includes agent.errors[:name], "can't be blank"
  end

  test "validates uniqueness of sip_account" do
    agent = Agent.new(name: "Dup", sip_account: agents(:one).sip_account, user: users(:one))
    assert_not agent.valid?
    assert_includes agent.errors[:sip_account], "has already been taken"
  end

  test "status enum" do
    agent = agents(:one)
    assert agent.offline?

    agent.online!
    assert agent.online?
  end

  test "available scope returns online agents" do
    agents(:one).update!(status: :online)
    agents(:two).update!(status: :offline)

    assert_includes Agent.available, agents(:one)
    assert_not_includes Agent.available, agents(:two)
  end

  test "belongs to user" do
    assert_equal users(:two), agents(:one).user
  end

  test "has many queue_configs through memberships" do
    assert_includes agents(:one).queue_configs, queue_configs(:one)
  end
end
