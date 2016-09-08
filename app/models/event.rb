class Event < ActiveRecord::Base
  has_many :event_batches, dependent: :destroy
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def self.sorted_active_events
    self.where(status: '1').order('lower(name)')
  end
end