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
  validate :unique_record

  def nilify_blank_values
    attributes.each { |col, val| self[col].present? || self[col] = nil }
  end

  def unique_record
    record = OnSiteAttendee.where([
      "event_id = ? and lower(first_name) = ? and " +
      "lower(last_name) = ? and lower(account_name) = ? and " +
      "account_number = ?", event_id,
      first_name.strip.downcase, last_name.strip.downcase,
      account_name.strip.downcase, account_number.strip
    ])

    if record.any?
      errors.add(:attendee, "already has a badge for this event.<br />" +
                            "Go to All Badges to update/print it.")
    end
  end
end