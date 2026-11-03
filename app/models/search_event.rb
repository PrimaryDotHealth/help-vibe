# One search, from the help center, the widget, the API or the admin.
# outcome: found (a result was opened), dead_end (no results), bounced (results, none opened).
class SearchEvent < ApplicationRecord
  belongs_to :clicked_article, class_name: "Article", optional: true
  belongs_to :user, optional: true

  def self.log!(query:, results_count:, source:, user: nil, page_context: nil, visitor_hash: nil)
    create!(query: query, normalized: query.to_s.downcase.squish, results_count: results_count,
            outcome: results_count.zero? ? "dead_end" : "bounced", source: source,
            user: user, page_context: page_context, visitor_hash: visitor_hash)
  end

  def clicked!(article)
    update!(clicked_article: article, outcome: "found")
  end
end
