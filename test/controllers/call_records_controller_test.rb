require "test_helper"

class CallRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "index" do
    get call_records_path
    assert_response :success
  end

  test "index with filters" do
    get call_records_path, params: { queue_id: queue_configs(:one).id, status: "completed" }
    assert_response :success
  end

  test "show" do
    get call_record_path(call_records(:one))
    assert_response :success
  end
end
