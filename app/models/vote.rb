# "Did this answer your question?" One vote per visitor per article; the
# visitor is a daily-rotating hash, never a raw IP.
class Vote < ApplicationRecord
  belongs_to :article
  belongs_to :user, optional: true
  validates :value, inclusion: { in: [ -1, 1 ] }

  def self.record!(article:, value:, visitor_hash:, source:, user: nil)
    transaction do
      vote = find_or_initialize_by(article: article, visitor_hash: visitor_hash)
      previous = vote.persisted? ? vote.value : 0
      vote.update!(value: value, source: source, user: user)
      Article.update_counters(article.id, upvotes: (value == 1 ? 1 : 0) - (previous == 1 ? 1 : 0),
                                          downvotes: (value == -1 ? 1 : 0) - (previous == -1 ? 1 : 0))
      vote
    end
  end
end
