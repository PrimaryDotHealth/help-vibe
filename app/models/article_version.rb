# A publishable copy of an article. Exactly one published version per
# language is the default (live) one, enforced by a partial unique index.
class ArticleVersion < ApplicationRecord
  class StaleRevision < StandardError; end

  belongs_to :article
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :current_revision, class_name: "Revision", optional: true
  has_many :revisions, -> { order(:id) }, foreign_key: :version_id, dependent: :destroy, inverse_of: :version
  has_many :reviews, -> { order(:created_at) }, foreign_key: :version_id, dependent: :destroy
  has_many :comments, -> { order(:created_at) }, foreign_key: :version_id, dependent: :destroy

  def open_review = reviews.reverse.find { _1.status != "cancelled" }

  # Publishing rules (S14): draft writers never publish. Others may unless a
  # review is required/open and not approved, in which case only bypass roles may.
  def publish_blocked_for(user)
    return "Draft writers can't publish. Request a review instead." unless user.can_publish?
    review = open_review
    needs_approval = Setting["review.required"] || review&.status.in?(%w[pending changes_requested])
    return nil unless needs_approval && review&.status != "approved"
    return nil if Array(Setting["review.bypass_roles"]).include?(user.role)
    review ? "Waiting for review approval" : "An approved review is required before publishing"
  end

  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }

  def draft? = status == "draft"

  scope :due_to_publish, -> { where(status: "draft").where(publish_at: ..Time.current) }
  scope :due_to_expire, -> { where(is_default: true).where(expire_at: ..Time.current) }

  validate :expiry_after_go_live

  def scheduled? = draft? && publish_at.present? && publish_at.future?

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
      Activity.record!(article, "publish", by: by, automatic: by.nil?)
    end
  end

  def expiry_after_go_live
    errors.add(:expire_at, "must be after the go-live time") if publish_at && expire_at && expire_at <= publish_at
  end

  def unpublish!(by:)
    transaction do
      update!(is_default: false, status: "draft", expire_at: nil)
      SearchIndex.remove!(article, language)
      Activity.record!(article, "unpublish", by: by, automatic: by.nil?)
    end
  end
end
