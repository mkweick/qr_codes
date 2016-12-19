class CrmCampaign < ActiveRecord::Base
  belongs_to :event

  validates :code,
    presence: { message: "Campaign code is required. Contact IT." },
    uniqueness: {
      scope: :event_id, case_sensitive: false,
      message: "Campaign already assigned to this event."
    }
  validates :name,
    presence: { message: "Campaign name is required. Contact IT." }
  validates :event_start_date,
    presence: { message: "Event start date not set on CRM Campaign." }
  validates :event_end_date,
    presence: { message: "Event end date not set on CRM Campaign." }
  validates :campaign_id,
    presence: { message: "Issue with this Campaign's CRM CampaignId." }
end