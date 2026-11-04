# Field-level encryption (webhook secrets, later TOTP secrets) with keys derived
# from secret_key_base, so there's no extra secret to manage. Rotating
# secret_key_base means re-entering encrypted fields (webhook secrets).
Rails.application.config.to_prepare do
  generator = Rails.application.key_generator
  ActiveRecord::Encryption.configure(
    primary_key: generator.generate_key("active_record_encryption.primary_key", 32).unpack1("H*"),
    deterministic_key: generator.generate_key("active_record_encryption.deterministic_key", 32).unpack1("H*"),
    key_derivation_salt: generator.generate_key("active_record_encryption.key_derivation_salt", 32).unpack1("H*")
  )
end
