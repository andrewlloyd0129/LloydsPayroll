class Task < ApplicationRecord
  enum status: { active: 0, inactive: 1}
end