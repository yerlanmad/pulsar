require "test_helper"

class CallRecordTest < ActiveSupport::TestCase
  test "status enum" do
    call = call_records(:one)
    assert call.completed?
  end

  test "duration_display formats correctly" do
    call = CallRecord.new(duration: 125)
    assert_equal "2:05", call.duration_display
  end

  test "duration_display returns -- when nil" do
    call = CallRecord.new(duration: nil)
    assert_equal "--", call.duration_display
  end

  test "today scope" do
    call = call_records(:one)
    call.update!(started_at: Time.current)
    assert_includes CallRecord.today, call
  end

  test "recent scope orders by started_at desc" do
    records = CallRecord.recent
    assert records.first.started_at >= records.last.started_at if records.count > 1
  end
end
