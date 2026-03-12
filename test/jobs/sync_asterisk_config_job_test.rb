require "test_helper"

class SyncAsteriskConfigJobTest < ActiveJob::TestCase
  test "enqueues with config type" do
    assert_enqueued_with(job: SyncAsteriskConfigJob, args: [ :pjsip ]) do
      SyncAsteriskConfigJob.perform_later(:pjsip)
    end
  end

  test "enqueues with queues config type" do
    assert_enqueued_with(job: SyncAsteriskConfigJob, args: [ :queues ]) do
      SyncAsteriskConfigJob.perform_later(:queues)
    end
  end

  test "enqueues with extensions config type" do
    assert_enqueued_with(job: SyncAsteriskConfigJob, args: [ :extensions ]) do
      SyncAsteriskConfigJob.perform_later(:extensions)
    end
  end
end
