class Event < ActiveRecord::Base
  has_many :batches, dependent: :destroy

  validates :name, presence: { message: 'Event type/year are required.' }
  validates_uniqueness_of :name, { case_sensitive: false,
    conditions: -> { where("status != '3'")},
    message: 'Event already active or archived.'
  }

  def self.sorted_active_events
    self.where(status: '1').order('lower(name)')
  end
end