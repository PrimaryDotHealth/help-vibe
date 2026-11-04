# A "chapter" in the UI. Top-level chapters carry a short code (SCH) that
# prefixes every article code in them (SCH·07).
class Category < ApplicationRecord
  ACCESSIBILITY = %w[public internal private].freeze

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, -> { order(:position, :name) }, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :articles, foreign_key: :main_category_id, dependent: :restrict_with_error

  normalizes :code, with: ->(c) { c.strip.upcase.presence }
  normalizes :slug, with: ->(s) { s.to_s.parameterize }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :code, format: { with: /\A[A-Z]{2,4}\z/ }, uniqueness: true, allow_nil: true
  validates :code, presence: true, if: -> { parent_id.nil? }
  validates :code, absence: true, if: -> { parent_id.present? }
  validates :accessibility, inclusion: { in: ACCESSIBILITY }

  has_many :access_grants, class_name: "CategoryAccess", dependent: :delete_all

  before_validation { self.slug = name if slug.blank? && name.present? }
  validate :not_less_restricted_than_parent
  after_update :tighten_children, if: :saved_change_to_accessibility?

  def restrictiveness = ACCESSIBILITY.index(accessibility)

  scope :chapters, -> { where(parent_id: nil, archived_at: nil).order(:position, :name) }
  scope :live, -> { where(archived_at: nil) }

  def to_param = slug

  def chapter
    parent ? parent.chapter : self
  end

  private
    # A sub-chapter can't be more visible than its parent.
    def not_less_restricted_than_parent
      return unless parent && restrictiveness < parent.restrictiveness
      errors.add(:accessibility, "can't be more open than its parent chapter (#{parent.accessibility})")
    end

    def tighten_children
      children.each { _1.update!(accessibility: accessibility) if _1.restrictiveness < restrictiveness }
    end

  public

  # The most restrictive accessibility on the way up the tree wins.
  def effective_accessibility
    chain = [ self ]
    chain << chain.last.parent while chain.last.parent
    chain.map(&:accessibility).max_by { ACCESSIBILITY.index(_1) }
  end
end
