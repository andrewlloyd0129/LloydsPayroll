class TimeEntry < ApplicationRecord
  enum status: { active: 0, pending: 1, approved: 2, rejected: 3}
  belongs_to :user
  has_many :task_entries, :dependent => :destroy

  accepts_nested_attributes_for :task_entries, allow_destroy: true

  def self.todays_entries ents
  	ents.select { |e| e.start_date.today? == true}
  end

  def self.this_weeks_entries ents
  	x = TimeEntry.find_start_of_week
  	ents.select { |e| e.start_date.between?(x, Date.today) == true }
  end

  def self.find_start_of_week
  	d = Date.today
  	while true
  		if d.wday == 1
  			break
  		end
  		d -= 1
  	end
  	d
  end
end