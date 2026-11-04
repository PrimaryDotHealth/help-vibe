class Company < ApplicationRecord
  has_many :contacts, dependent: :nullify
end
