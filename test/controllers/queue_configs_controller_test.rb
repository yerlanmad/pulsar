require "test_helper"

class QueueConfigsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @queue = queue_configs(:one)
  end

  test "index" do
    get queue_configs_path
    assert_response :success
  end

  test "show" do
    get queue_config_path(@queue)
    assert_response :success
  end

  test "new" do
    get new_queue_config_path
    assert_response :success
  end

  test "create" do
    assert_difference("QueueConfig.count") do
      post queue_configs_path, params: { queue_config: { name: "New Queue", strategy: "ringall", timeout: 30, max_wait_time: 300, timeout_action: "hangup" } }
    end
    assert_redirected_to queue_config_path(QueueConfig.last)
  end

  test "update" do
    patch queue_config_path(@queue), params: { queue_config: { timeout: 45 } }
    assert_redirected_to queue_config_path(@queue)
    assert_equal 45, @queue.reload.timeout
  end

  test "destroy" do
    assert_difference("QueueConfig.count", -1) do
      delete queue_config_path(@queue)
    end
    assert_redirected_to queue_configs_path
  end
end
