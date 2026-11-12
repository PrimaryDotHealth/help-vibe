class ArticleCollection < ApplicationRecord
  self.primary_key = %i[article_id collection_id]
  belongs_to :article
  belongs_to :collection
end
