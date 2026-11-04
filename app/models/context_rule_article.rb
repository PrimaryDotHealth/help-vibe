class ContextRuleArticle < ApplicationRecord
  self.primary_key = %i[rule_id article_id]
  belongs_to :rule, class_name: "ContextRule", inverse_of: :rule_articles
  belongs_to :article
end
