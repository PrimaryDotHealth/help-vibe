require "test_helper"

class BackupJobTest < ActiveJob::TestCase
  test "does nothing without a backup key" do
    key = ENV.delete("HELPVIBE_BACKUP_KEY")
    assert_nil BackupJob.perform_now
  ensure
    ENV["HELPVIBE_BACKUP_KEY"] = key if key
  end
end
