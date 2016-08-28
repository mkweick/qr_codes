class Location < ActiveRecord::Base
	validates :city, presence: true, uniqueness: { case_sensitive: false }

  def city=(fn)
    write_attribute(:city, fn.strip)
  end

	def self.sorted_cities
		self.pluck(:city).sort
	end
end
