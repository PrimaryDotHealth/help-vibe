class ViewEvent < ApplicationRecord
  belongs_to :article
  belongs_to :version, class_name: "ArticleVersion", optional: true
  belongs_to :search_event, optional: true
  belongs_to :user, optional: true
end
