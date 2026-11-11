require "open3"

module Helpvibe
  # Nightly database backup: pg_dump (custom format) encrypted with
  # AES-256-GCM using HELPVIBE_BACKUP_KEY, written to storage/backups (on the
  # encrypted disk, in the same volume as uploads), keeping the newest 14.
  #
  # File layout: "HVB1" | 12-byte IV | ciphertext | 16-byte auth tag
  module Backup
    MAGIC = "HVB1".b
    KEEP = 14

    def self.dir = Rails.root.join("storage", "backups")

    def self.key
      hex = ENV["HELPVIBE_BACKUP_KEY"].presence or raise "HELPVIBE_BACKUP_KEY is not set (openssl rand -hex 32)"
      [ hex ].pack("H*").tap { raise "HELPVIBE_BACKUP_KEY must be 64 hex characters" unless _1.bytesize == 32 }
    end

    def self.run!(now: Time.current)
      FileUtils.mkdir_p(dir)
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      env = { "PGPASSWORD" => config[:password].to_s }
      args = [ "pg_dump", "--format=custom", "--no-owner", "--host", (config[:host] || "localhost").to_s,
               "--port", (config[:port] || 5432).to_s,
               "--username", (config[:username] || ENV["USER"]).to_s, config[:database].to_s ]
      dump, err, status = Open3.capture3(env, *args, binmode: true)
      raise "pg_dump failed: #{err}" unless status.success?

      path = dir.join("helpvibe-#{now.utc.strftime("%Y%m%d-%H%M%S")}.dump.enc")
      File.binwrite(path, encrypt(dump))
      prune!
      path
    end

    def self.encrypt(data)
      cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
      cipher.key = key
      iv = cipher.random_iv
      MAGIC + iv + cipher.update(data) + cipher.final + cipher.auth_tag
    end

    def self.decrypt(blob)
      raise "not a helpvibe backup" unless blob.byteslice(0, 4) == MAGIC
      cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
      cipher.key = key
      cipher.iv = blob.byteslice(4, 12)
      cipher.auth_tag = blob.byteslice(-16, 16)
      cipher.update(blob.byteslice(16...-16)) + cipher.final
    end

    def self.prune!
      Dir[dir.join("helpvibe-*.dump.enc")].sort.reverse.drop(KEEP).each { File.delete(_1) }
    end
  end
end
