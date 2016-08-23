class Location < ActiveRecord::Base
	validates :city, presence: true, uniqueness: { case_sensitive: false }

	def self.sorted_cities
		self.pluck(:city).sort
	end
end
