# "Also listed in" chapters. The main chapter is articles.main_category_id.
class ArticleCategory < ApplicationRecord
  self.primary_key = %i[article_id category_id]
  belongs_to :article
  belongs_to :category
end
