class CrmCampaignsController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_event
  before_action :require_active_event
  before_action :set_crm_campaign, except: [:create, :search]


  def create
    name = params[:name].strip unless params[:name].blank?
    code = params[:code].strip unless params[:code].blank?
    
    if name && code 
      @campaign = @event.crm_campaigns.new(name: name, code: code)

      if @campaign.save
        flash.notice = "CRM Campaign assigned."
        redirect_to edit_event_path(@event)
      else
        set_event_form_info
        render 'events/edit'
      end
    else
      flash.alert = "Campaign Name or Code missing. Contact IT."
      redirect_to edit_event_path(@event)
    end
  end

  def destroy
    if @campaign
      if @campaign.destroy
        flash.notice = "CRM Campaign unassigned."
      else
        flash.alert = "CRM Campaign can't be deleted. Contact IT."
      end
    else
      flash.alert = "CRM Campaign doesn't exist."
    end
    redirect_to edit_event_path(@event)
  end

  def search
    name = params[:name].strip unless params[:name].blank?
    @results = []

    if name
      db = TinyTds::Client.new(
        host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
        username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
      )

      name = db.escape(name)

      query = db.execute(
        "SELECT Name, CodeName FROM CampaignBase
         WHERE Name LIKE '%#{name}%'"
      )

      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?
    end
  end

  private

  def crm_campaign_params
    params.require(:crm_campaign).permit(:code)
  end

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def set_crm_campaign
    @campaign = CrmCampaign.find(params[:id]) if params[:id]
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