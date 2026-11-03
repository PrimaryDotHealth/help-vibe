# A publishable copy of an article. Exactly one published version per
# language is the default (live) one, enforced by a partial unique index.
class ArticleVersion < ApplicationRecord
  class StaleRevision < StandardError; end

  belongs_to :article
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :current_revision, class_name: "Revision", optional: true
  has_many :revisions, -> { order(:id) }, foreign_key: :version_id, dependent: :destroy, inverse_of: :version

  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }

  def draft? = status == "draft"

  # Every save (manual or autosave) is a new revision. Saving on top of a
  # revision that is no longer current raises StaleRevision (HTTP 409), so two
  # editors can't silently overwrite each other.
  def save_revision!(body:, author:, base_revision_id:, autosave: false, title: nil, subtitle: nil)
    with_lock do
      if base_revision_id.present? && current_revision_id.present? && base_revision_id.to_i != current_revision_id
        raise StaleRevision
      end
      rev = revisions.create!(body: body, author: author, autosave: autosave, base_revision_id: current_revision_id)
      attrs = { current_revision: rev }
      attrs[:title] = title if title.present?
      attrs[:subtitle] = subtitle unless subtitle.nil?
      update!(attrs)
      rev
    end
  end

  # One transaction: retire the old default, make this one live, refresh the
  # search index, record the activity.
  def publish!(by:)
    raise ArgumentError, "nothing to publish" unless current_revision
    transaction do
      article.lock!
      article.versions.where(language: language, is_default: true).where.not(id: id).update_all(is_default: false)
      update!(status: "published", is_default: true, published_at: Time.current, publish_at: nil)
      SearchIndex.refresh!(self)
      Activity.record!(article, "publish", by: by)
    end
  end

  def unpublish!(by:)
    transaction do
      update!(is_default: false, status: "draft")
      SearchIndex.remove!(article, language)
      Activity.record!(article, "unpublish", by: by)
    end
  end
end
