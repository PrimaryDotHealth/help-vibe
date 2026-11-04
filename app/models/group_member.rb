class GroupMember < ApplicationRecord
  self.primary_key = %i[group_id user_id]
  belongs_to :group
  belongs_to :user
end
