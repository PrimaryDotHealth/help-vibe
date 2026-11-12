# A named set of articles, usually one per customer organization ("Acme")
# plus any shared ones ("General"). Embeds pick collections by slug:
# ?collections=acme,general. An article can be in any number of them.
class Collection < ApplicationRecord
  has_many :article_collections, dependent: :delete_all
  has_many :articles, through: :article_collections

  normalizes :slug, with: ->(s) { s.to_s.parameterize }

  before_validation { self.slug = name if slug.blank? && name.present? }
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def to_param = slug

  # "acme, general" or ["acme", "general"] -> ["acme", "general"]
  def self.slugs_from(input)
    Array(input).flat_map { _1.to_s.split(",") }.map { _1.strip.parameterize }.compact_blank.uniq.first(20)
  end
end
