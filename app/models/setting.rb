# Site-wide switches, one row per key (table `settings`, value is JSON).
# Unset keys fall back to DEFAULTS, so a fresh install needs no rows.
class Setting < ApplicationRecord
  self.primary_key = "key"

  DEFAULTS = {
    "help_center_contact" => true   # "Contact support" in the help center
  }.freeze

  def self.[](key)
    key = key.to_s
    raise ArgumentError, "unknown setting #{key}" unless DEFAULTS.key?(key)
    row = find_by(key: key)
    row ? row.value : DEFAULTS[key]
  end

  def self.[]=(key, value)
    key = key.to_s
    raise ArgumentError, "unknown setting #{key}" unless DEFAULTS.key?(key)
    upsert({ key: key, value: value, updated_at: Time.current }, unique_by: :key)
  end

  def self.help_center_contact? = self[:help_center_contact] == true
end
