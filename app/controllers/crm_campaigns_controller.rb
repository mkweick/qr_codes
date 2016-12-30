class CrmCampaignsController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_event
  before_action :require_active_event
  before_action :set_crm_campaign, except: [:create, :search]


  def create
    @campaign = @event.crm_campaigns.new(crm_campaign_params)

    if @campaign.save
      flash.notice = "CRM Campaign assigned."
      redirect_to edit_event_path(@event)
    else
      set_event_form_info
      render 'events/edit'
    end
  end

  def destroy
    if @campaign.destroy
      flash.notice = "CRM Campaign unassigned."
    else
      flash.alert = "CRM Campaign can't be deleted. Contact IT."
    end

    redirect_to edit_event_path(@event)
  end

  def search
    campaign_name = params[:name].strip unless params[:name].blank?
    @results = []

    if campaign_name
      db = crm_connection_sql
      campaign_name = db.escape(campaign_name)
      sql = "SELECT Name, CodeName, ActualStart, ActualEnd, CampaignId " +
        "FROM CampaignBase WHERE Name LIKE '%#{campaign_name}%'"
      query = db.execute(sql)
      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def set_crm_campaign
    @campaign = CrmCampaign.find(params[:id]) if params[:id]
  end

  def crm_campaign_params
    campaign_name = params[:campaign_name].strip unless params[:campaign_name].blank?
    code = params[:code].strip unless params[:code].blank?
    start_date = params[:start_date].strip unless params[:start_date].blank?
    end_date = params[:end_date].strip unless params[:end_date].blank?
    campaign_id = params[:campaign_id].strip unless params[:campaign_id].blank?
    
    { name: campaign_name, code: code, event_start_date: start_date,
      event_end_date: end_date, campaign_id: campaign_id }
  end

  def set_event_form_info
    event_name = @event.name.split(' ')
    @year = event_name.pop
    @years = Time.now.year..(Time.now.year + 2)
    @type = event_name.join(' ')
    @types = Type.sorted_types.pluck(:name)

    @campaigns = @event.crm_campaigns.order(:name)
  end
end