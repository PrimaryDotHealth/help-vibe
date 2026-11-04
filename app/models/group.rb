class Group < ApplicationRecord
  has_many :group_members, dependent: :delete_all
  has_many :users, through: :group_members
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # auto_join_domains is text[]; edited as "primary.health, example.com"
  def domain_list = auto_join_domains.join(", ")
  def domain_list=(text)
    self.auto_join_domains = text.to_s.split(",").map { _1.strip.downcase.delete_prefix("@") }.compact_blank.uniq
  end

  def self.auto_join!(user)
    domain = user.email_address.split("@").last
    where("? = any(auto_join_domains)", domain).find_each { |g| g.group_members.find_or_create_by!(user: user) }
  end
end
