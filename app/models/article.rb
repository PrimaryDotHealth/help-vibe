# An article is the stable thing readers link to (slug, code SCH·07). Its
# content lives in versions (publishable copies), and each version in
# revisions (every save). See replica/architecture.md, "the editing model".
class Article < ApplicationRecord
  ACCESSIBILITY = %w[public internal private url_only].freeze
  CODE = /\A([A-Z]{2,4})·(\d{2,3})\z/

  belongs_to :main_category, class_name: "Category"
  belongs_to :created_by, class_name: "User", optional: true
  has_many :versions, -> { order(:number) }, class_name: "ArticleVersion", dependent: :destroy
  has_many :article_keywords, dependent: :delete_all
  has_many :keywords, through: :article_keywords

  validates :slug, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true, format: { with: CODE }
  validates :accessibility, inclusion: { in: ACCESSIBILITY }

  normalizes :slug, with: ->(s) { s.to_s.parameterize }

  before_validation :assign_code, on: :create

  scope :live, -> { where(archived_at: nil) }
  scope :published, -> { where(id: ArticleVersion.where(is_default: true).select(:article_id)) }

  has_many :access_grants, class_name: "ArticleAccess", dependent: :delete_all

  # Articles a viewer may see in lists (contents page, chapter pages).
  def self.listed_for(viewer)
    live.published.joins(:main_category).where(Visibility.sql(viewer))
  end

  # Opening an article by its link also allows "url_only".
  def visible_to?(viewer)
    Article.joins(:main_category).where(id: id).where(Visibility.sql(viewer, by_link: true)).exists?
  end

  # Who may see it when it's private: [[:user, id], [:group, id]]
  def accessor_keys
    access_grants.map { _1.user_id ? "user:#{_1.user_id}" : "group:#{_1.group_id}" }
  end

  def accessor_keys=(keys)
    pairs = Array(keys).compact_blank.map { _1.split(":") }.select { %w[user group].include?(_1.first) }
    transaction do
      access_grants.delete_all
      pairs.each { |kind, id| access_grants.create!("#{kind}_id" => id.to_i) }
    end
  end

  def to_param = slug

  # Accepts "SCH·07", "sch07", "SCH-7", "sch 07".
  def self.normalize_code(input)
    m = input.to_s.strip.upcase.match(/\A([A-Z]{2,4})[\s·.\-_]*(\d{1,3})\z/)
    "#{m[1]}·#{m[2].rjust(2, "0")}" if m
  end

  def self.find_by_code_query(input)
    code = normalize_code(input)
    live.find_by(code: code) if code
  end

  # Creates the article with its first draft version and an empty revision.
  def self.start!(title:, category:, author:, accessibility: "public")
    transaction do
      article = create!(slug: unique_slug(title), main_category: category, created_by: author, accessibility: accessibility)
      article.versions.create!(number: 1, title: title, created_by: author)
      article
    end
  end

  def self.unique_slug(title)
    base = title.to_s.parameterize.presence || "article"
    slug = base
    n = 1
    slug = "#{base}-#{n += 1}" while exists?(slug: slug)
    slug
  end

  def live_version(language = "en_US")
    versions.find_by(is_default: true, language: language)
  end

  # The draft people should be editing: an open draft if there is one,
  # otherwise a new draft copied from the live version (the live copy is
  # never edited in place).
  def working_version!(author:)
    versions.where(status: "draft").order(:number).last || begin
      live = live_version || versions.last
      transaction do
        draft = versions.create!(number: (versions.maximum(:number) || 0) + 1, language: live.language,
                                 title: live.title, subtitle: live.subtitle, created_by: author)
        if (rev = live.current_revision)
          draft.save_revision!(body: rev.body_html, author: author, base_revision_id: nil)
        end
        draft
      end
    end
  end

  def keyword_list
    keywords.order(:name).pluck(:name).join(", ")
  end

  def keyword_list=(text)
    names = text.to_s.split(",").map(&:strip).compact_blank.uniq(&:downcase)
    self.keywords = names.map { |n| Keyword.where("name = ?", n).first || Keyword.create!(name: n) }
  end

  # "Live", "Live, editing v3", "Goes live 1 Jan" or "Draft" (S11).
  def status_label
    live = versions.find(&:is_default)
    draft = versions.select { _1.status == "draft" }.max_by(&:number)
    if live && draft then "Live, editing v#{draft.number}"
    elsif live then "Live"
    elsif draft&.publish_at then "Goes live #{draft.publish_at.strftime("%-d %b")}"
    else "Draft"
    end
  end

  def status_key
    return "live" if versions.any?(&:is_default)
    versions.any? { _1.status == "draft" && _1.publish_at } ? "scheduled" : "draft"
  end

  private
    def assign_code
      return if code.present? || main_category.nil?
      prefix = main_category.chapter.code
      used = Article.where("code like ?", "#{prefix}·%").pluck(:code).map { _1.split("·").last.to_i }
      self.code = "#{prefix}·#{((used.max || 0) + 1).to_s.rjust(2, "0")}"
    end
end
