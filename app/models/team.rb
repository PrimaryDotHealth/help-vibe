class Team < ApplicationRecord
  has_many :team_members, dependent: :delete_all
  has_many :users, through: :team_members
  has_many :threads, class_name: "SupportThread", foreign_key: :assignee_team_id, dependent: :nullify
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
