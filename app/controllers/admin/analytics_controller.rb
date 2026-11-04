# S19: what readers need. All numbers come from our own tables; no
# third-party analytics, no cookies.
class Admin::AnalyticsController < Admin::BaseController
  RANGES = { "7" => 7, "30" => 30, "90" => 90 }.freeze
  SOURCES = { "all" => nil, "widget" => "widget", "kb" => "kb", "api" => "api" }.freeze

  def show
    @days = RANGES.fetch(params[:days], 30)
    @source = SOURCES.key?(params[:source]) ? params[:source] : "all"
    since = @days.days.ago.beginning_of_day
    previous = (since - @days.days)...since

    searches = SearchEvent.where(created_at: since..)
    searches = searches.where(source: SOURCES[@source]) if SOURCES[@source]
    prev_searches = SearchEvent.where(created_at: previous)
    prev_searches = prev_searches.where(source: SOURCES[@source]) if SOURCES[@source]
    views = ViewEvent.where(created_at: since..)
    views = views.where(source: SOURCES[@source]) if SOURCES[@source] && @source != "api"

    @total = searches.count
    @dead_ends = searches.where(outcome: "dead_end").count
    @answered_pct = pct(@total - @dead_ends, @total)
    @prev_answered_pct = pct(prev_searches.count - prev_searches.where(outcome: "dead_end").count, prev_searches.count)
    @views = views.count
    @prev_views = ViewEvent.where(created_at: previous).count
    votes = Vote.where(created_at: since..)
    @helpful_pct = pct(votes.where(value: 1).count, votes.count)

    @series = daily(searches, since)
    @dead_series = daily(searches.where(outcome: "dead_end"), since)

    @no_answer = searches.where(outcome: "dead_end").where.not(normalized: [ nil, "" ])
                         .group(:normalized).order(Arel.sql("count(*) desc")).limit(15).count
    @no_answer_pages = searches.where(outcome: "dead_end").where.not(page_context: nil)
                               .group(:normalized, :page_context).count
                               .each_with_object({}) { |((q, page), n), h| h[q] = page if !h[q] || n > h[q].last.to_i }
    @top_articles = Article.where(id: views.group(:article_id).order(Arel.sql("count(*) desc")).limit(10).select(:article_id))
                           .includes(:versions).index_by(&:id)
    @top_counts = views.group(:article_id).order(Arel.sql("count(*) desc")).limit(10).count
    @pages = (searches.where.not(page_context: nil).group(:page_context).count)
             .merge(views.where.not(page_context: nil).group(:page_context).count) { |_, a, b| a + b }
             .sort_by { -_2 }.first(8)
    @page_dead_ends = searches.where(outcome: "dead_end").where.not(page_context: nil).group(:page_context).count
    @not_helpful = Vote.where(value: -1).where.not(comment: "").includes(article: :versions).order(created_at: :desc).limit(8)

    respond_to do |format|
      format.html
      format.csv { send_data no_answer_csv, filename: "no-answer-searches-#{Date.current}.csv" }
    end
  end

  private
    def pct(part, whole) = whole.to_i.zero? ? nil : (100.0 * part / whole).round

    def daily(scope, since)
      counts = scope.group(Arel.sql("date(created_at at time zone 'UTC')")).count
      (since.to_date..Date.current).map { [ _1, counts[_1].to_i ] }
    end

    def no_answer_csv
      CSV.generate { |csv| csv << %w[query searches]; @no_answer.each { csv << _1 } }
    end
end
