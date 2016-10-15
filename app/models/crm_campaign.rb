class CrmCampaign < ActiveRecord::Base
  belongs_to :event

  validates :code,
    presence: { message: "Campaign code is required. Contact IT." },
    uniqueness: {
      case_sensitive: false,
      message: "Campaign already assigned to this event"
    }
  validates :name,
    presence: { message: "Campaign name is required. Contact IT." }
end