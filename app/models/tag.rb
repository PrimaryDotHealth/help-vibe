class Tag < ApplicationRecord
  has_many :thread_tags, dependent: :delete_all
  validates :name, presence: true
end
