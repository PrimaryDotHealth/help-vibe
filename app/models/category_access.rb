class CategoryAccess < ApplicationRecord
  self.table_name = "category_access"
  belongs_to :category
  belongs_to :user, optional: true
  belongs_to :group, optional: true
end
