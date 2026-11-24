# One saved snapshot of a version. The body is Action Text (edited with
# Lexxy); body_text is the plain-text copy used for search, diffs and email.
class Revision < ApplicationRecord
  belongs_to :version, class_name: "ArticleVersion", inverse_of: :revisions
  belongs_to :author, class_name: "User", optional: true

  has_rich_text :body

  validates :body_format, inclusion: { in: %w[html markdown] }

  before_save { self.body_text = self.class.plain_text(body_html) }

  scope :meaningful, -> { where(autosave: false) }

  # The stored (canonical) HTML, for copying into a new revision. Not
  # `body.to_s`, which wraps it in a display layout.
  def body_html = body&.body&.to_html.to_s

  # Action Text's plain-text conversion runs headings and table cells into
  # the next block ("Reschedule1. Open Calendar"). Treat them as paragraphs.
  def self.plain_text(html)
    doc = Nokogiri::HTML5.fragment(html.to_s)
    doc.css("h1, h2, h3, h4, h5, h6").each { _1.name = "p" }
    doc.css("td, th").each { _1.add_child(" ") }
    ActionText::Content.new(doc.to_html).to_plain_text.squish
  end
end
