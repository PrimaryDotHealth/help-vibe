class Keyword < ApplicationRecord
  has_many :article_keywords, dependent: :delete_all
  has_many :articles, through: :article_keywords
  validates :name, presence: true
end
