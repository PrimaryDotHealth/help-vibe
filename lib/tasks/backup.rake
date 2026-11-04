namespace :helpvibe do
  namespace :backup do
    desc "Take an encrypted database backup now (needs HELPVIBE_BACKUP_KEY)"
    task now: :environment do
      puts "Wrote #{Helpvibe::Backup.run!}"
    end

    desc "Decrypt a backup: bin/rails 'helpvibe:backup:decrypt[storage/backups/x.dump.enc]' > x.dump  (then pg_restore)"
    task :decrypt, [ :path ] => :environment do |_, args|
      $stdout.binmode
      $stdout.write Helpvibe::Backup.decrypt(File.binread(args[:path]))
    end
  end
end
