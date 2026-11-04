require "test_helper"

class BackupTest < ActiveSupport::TestCase
  setup do
    @key = ENV["HELPVIBE_BACKUP_KEY"]
    ENV["HELPVIBE_BACKUP_KEY"] = SecureRandom.hex(32)
    @dir = Dir.mktmpdir
    Helpvibe::Backup.singleton_class.alias_method(:original_dir, :dir)
    dir = Pathname(@dir)
    Helpvibe::Backup.define_singleton_method(:dir) { dir }
  end

  teardown do
    ENV["HELPVIBE_BACKUP_KEY"] = @key
    Helpvibe::Backup.singleton_class.alias_method(:dir, :original_dir)
    FileUtils.rm_rf(@dir)
  end

  test "encrypts and decrypts, and tampering is detected" do
    sealed = Helpvibe::Backup.encrypt("patient data")
    assert_not_includes sealed, "patient data"
    assert_equal "patient data", Helpvibe::Backup.decrypt(sealed)
    tampered = sealed.dup
    tampered.setbyte(20, tampered.getbyte(20) ^ 1)
    assert_raises(OpenSSL::Cipher::CipherError) { Helpvibe::Backup.decrypt(tampered) }
  end

  test "a real pg_dump is written encrypted and old ones are pruned" do
    skip "pg_dump not installed" unless system("which pg_dump > /dev/null 2>&1")
    16.times { |i| File.write(File.join(@dir, "helpvibe-2026010#{i.to_s.rjust(2, "0")}-000000.dump.enc"), "old") }
    path = Helpvibe::Backup.run!
    dump = Helpvibe::Backup.decrypt(File.binread(path))
    assert dump.start_with?("PGDMP"), "custom-format pg_dump"
    assert_equal 14, Dir[File.join(@dir, "*.dump.enc")].size
    assert File.exist?(path)
  end
end
