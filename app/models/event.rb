class Event < ActiveRecord::Base
  has_many :crm_campaigns, dependent: :destroy
  has_many :batches, dependent: :destroy
  has_many :on_site_attendees, dependent: :destroy

  validates :name, presence: { message: 'Event type/year are both required.' }
  validates_uniqueness_of :name, {
    case_sensitive: false,
    conditions: -> { where("status != '3'") },
    message: 'Event already active or archived.'
  }
  validates_inclusion_of :multiple_locations, in: [true, false], 
    message: 'Multiple locations must be set to Yes or No.'
  validates :qr_code_email_subject,
    presence: { message: 'QR Code Email Subject required.' }

  def self.sorted_active_events
    self.where(status: '1').order('lower(name)')
  end

  def self.sorted_archives
    self.where(status: '2').order('lower(name)')
  end

  def self.sorted_deleted
    self.where(status: '3').order('lower(name)')
  end
end