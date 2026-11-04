class BackupJob < ApplicationJob
  queue_as :default
  def perform = Helpvibe::Backup.run!
end
