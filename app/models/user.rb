class User < ApplicationRecord
  # Helpjuice's five roles, most powerful first (replica/recon.md, "user roles").
  ROLES = %w[superadmin admin collaborator draft_writer viewer].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :group_members, dependent: :delete_all
  has_many :groups, through: :group_members
  has_many :team_members, dependent: :delete_all
  has_many :teams, through: :team_members
  has_many :notifications, dependent: :delete_all

  # Invitations: a signed link to choose a first password, valid for a week.
  generates_token_for :invitation, expires_in: 7.days do
    password_salt&.last(10)
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  scope :active, -> { where(active: true) }

  def self.authenticate_active(params)
    user = authenticate_by(params)
    user if user&.active?
  end

  def name
    [ first_name, last_name ].compact_blank.join(" ").presence || email_address
  end

  def initials
    name.split(/[\s@.]/).compact_blank.first(2).map { _1[0] }.join.upcase
  end

  def rank = ROLES.index(role)
  def at_least?(other) = rank <= ROLES.index(other.to_s)

  def editor?       = at_least?(:draft_writer)   # can use the admin and write drafts
  def can_publish?  = at_least?(:collaborator)
  def admin?        = at_least?(:admin)
  def superadmin?   = role == "superadmin"

  # Support agents: anyone in a support team, plus admins.
  def agent? = active? && (admin? || team_members.exists?)
end
