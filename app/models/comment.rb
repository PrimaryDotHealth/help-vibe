# Editor comments on a version (internal, never shown to readers). The quoted
# text is kept in anchor["quote"].
class Comment < ApplicationRecord
  belongs_to :version, class_name: "ArticleVersion"
  belongs_to :author, class_name: "User", optional: true
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, -> { order(:created_at) }, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true
  scope :unresolved, -> { where(resolved_at: nil) }
  scope :threads, -> { where(parent_id: nil) }

  def quote = anchor.is_a?(Hash) ? anchor["quote"] : nil
end
