class OnSiteAttendee < ActiveRecord::Base
  belongs_to :event

  before_save :nilify_blank_values, only: [:create, :update]

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :account_name, presence: true
  validates :street1, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip_code, presence: true
  validates :email, presence: true
  validates :phone, presence: true
  validates :badge_type, presence: true

  def self.sorted_attendees
    self.order('lower(last_name)', 'lower(first_name')
  end

  def nilify_blank_values
    attributes.each { |col, val| self[col].present? || self[col] = nil }
  end
end