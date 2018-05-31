class TimeEntry < ApplicationRecord
  enum status: { active: 0, pending: 1, approved: 2}
  belongs_to :user
  has_many :task_entries
end