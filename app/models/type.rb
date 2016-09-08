class Type < ActiveRecord::Base
	validates :name, presence: true, uniqueness: { case_sensitive: false }

  def name=(fn)
    write_attribute(:name, fn.strip)
  end

	def self.sorted_types
		self.order('lower(name)')
	end
end
