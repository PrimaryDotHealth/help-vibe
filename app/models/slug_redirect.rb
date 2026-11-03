class SlugRedirect < ApplicationRecord
  self.primary_key = "from_path"
  belongs_to :article, optional: true
  belongs_to :category, optional: true
end
