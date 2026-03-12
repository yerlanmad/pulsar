require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one) # admin
    @agent = agents(:one)
  end

  test "index" do
    get agents_path
    assert_response :success
  end

  test "show" do
    get agent_path(@agent)
    assert_response :success
  end

  test "new" do
    get new_agent_path
    assert_response :success
  end

  test "create" do
    new_user = User.create!(name: "New", email_address: "new@test.com", password: "password")
    assert_difference("Agent.count") do
      post agents_path, params: { agent: { name: "New Agent", sip_account: "9999", user_id: new_user.id } }
    end
    assert_redirected_to agent_path(Agent.last)
  end

  test "update" do
    patch agent_path(@agent), params: { agent: { name: "Updated" } }
    assert_redirected_to agent_path(@agent)
    assert_equal "Updated", @agent.reload.name
  end

  test "destroy" do
    assert_difference("Agent.count", -1) do
      delete agent_path(@agent)
    end
    assert_redirected_to agents_path
  end

  test "update_status" do
    patch update_status_agent_path(@agent, status: "online")
    assert_equal "online", @agent.reload.status
  end

  test "agent role cannot access index" do
    sign_in_as users(:two) # agent role
    get agents_path
    assert_redirected_to root_path
  end
end
