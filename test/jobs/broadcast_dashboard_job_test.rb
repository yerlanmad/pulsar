require "test_helper"

class BroadcastDashboardJobTest < ActiveJob::TestCase
  test "enqueues successfully" do
    assert_enqueued_with(job: BroadcastDashboardJob) do
      BroadcastDashboardJob.perform_later
    end
  end
end
