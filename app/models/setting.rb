# Knowledge-base-wide settings (S18), stored as JSON values with defaults.
class Setting < ApplicationRecord
  self.primary_key = "key"

  DEFAULTS = {
    "review.rule" => "any",                           # any | all reviewers must approve
    "review.bypass_roles" => %w[superadmin admin],    # may publish while a review is open
    "review.required" => false                        # if true, nothing publishes without an approved review
  }.freeze

  def self.[](key)
    row = find_by(key: key)
    row ? row.value : DEFAULTS.fetch(key)
  end

  def self.[]=(key, value)
    upsert({ key: key, value: value, updated_at: Time.current }, unique_by: :key)
  end
end
