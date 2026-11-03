class ArticleKeyword < ApplicationRecord
  self.primary_key = %i[article_id keyword_id]
  belongs_to :article
  belongs_to :keyword
end
