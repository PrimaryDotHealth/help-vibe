# Page suggestions for the widget: a pattern on our app's paths
# ("/billing/*", "/patients/**") -> an ordered list of articles.
class ContextRule < ApplicationRecord
  has_many :rule_articles, -> { order(:position) }, class_name: "ContextRuleArticle", foreign_key: :rule_id, dependent: :delete_all, inverse_of: :rule
  has_many :articles, through: :rule_articles

  validates :name, :url_pattern, presence: true
  validates :url_pattern, format: { with: %r{\A/[A-Za-z0-9_\-./:*~%]*\z}, message: "starts with / and uses path characters and * only" }

  # * matches within one path segment, ** matches across segments.
  def matches?(path)
    regex = Regexp.escape(url_pattern).gsub("\\*\\*", ".*").gsub("\\*", "[^/]*")
    path.to_s.match?(/\A#{regex}\/?\z/)
  end

  def self.for_page(path)
    return nil if path.blank?
    order(priority: :desc, id: :asc).includes(:articles).find { _1.matches?(path) }
  end

  # Edited as "SCH·07, BIL·02"
  def article_codes = articles.map(&:code).join(", ")
  def article_codes=(text)
    codes = text.to_s.split(/[,\s]+/).filter_map { Article.normalize_code(_1) }.uniq
    found = Article.where(code: codes).index_by(&:code)
    @missing_codes = codes - found.keys
    self.rule_articles = codes.filter_map.with_index { |c, i| found[c] && ContextRuleArticle.new(article: found[c], position: i) }
  end

  validate { errors.add(:article_codes, "not found: #{@missing_codes.join(", ")}") if @missing_codes.present? }
end
