class ArticleAccess < ApplicationRecord
  self.table_name = "article_access"
  belongs_to :article
  belongs_to :user, optional: true
  belongs_to :group, optional: true
end
