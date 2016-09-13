class Location < ActiveRecord::Base
	validates :name, presence: true, uniqueness: { case_sensitive: false }

  def city=(fn)
    write_attribute(:name, fn.strip)
  end

	def self.sorted_locations
		self.order('lower(name)')
	end
end
