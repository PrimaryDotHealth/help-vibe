# Nightly encrypted pg_dump to storage/backups. Needs HELPVIBE_BACKUP_KEY and a
# persistent disk; without the key it does nothing (e.g. on Porter, where the
# managed database's own snapshots are the backups).
class BackupJob < ApplicationJob
  queue_as :default

  def perform
    if ENV["HELPVIBE_BACKUP_KEY"].blank?
      Rails.logger.info("BackupJob skipped: HELPVIBE_BACKUP_KEY is not set")
      return
    end
    Helpvibe::Backup.run!
  end
end
