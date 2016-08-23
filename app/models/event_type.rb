class EventType < ActiveRecord::Base
	validates :name, presence: true, uniqueness: { case_sensitive: false }

	def self.sorted_types
		self.pluck(:name).sort
	end
end
