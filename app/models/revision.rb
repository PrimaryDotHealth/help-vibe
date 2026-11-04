# One saved snapshot of a version. The body is Action Text (edited with
# Lexxy); body_text is the plain-text copy used for search, diffs and email.
class Revision < ApplicationRecord
  belongs_to :version, class_name: "ArticleVersion", inverse_of: :revisions
  belongs_to :author, class_name: "User", optional: true

  has_rich_text :body

  validates :body_format, inclusion: { in: %w[html markdown] }

  before_save { self.body_text = body.to_plain_text.squish }

  scope :meaningful, -> { where(autosave: false) }

  # The stored (canonical) HTML, for copying into a new revision. Not
  # `body.to_s`, which wraps it in a display layout.
  def body_html = body&.body&.to_html.to_s
end
