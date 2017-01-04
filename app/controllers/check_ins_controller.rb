class CheckInsController < ApplicationController
  before_action :require_user
  before_action :set_event
  before_action :require_active_event
  before_action :require_assigned_crm_campaigns

  def new; end

  def attended
    update_crm_attendee_record('100000003')
  end

  def not_attended
    update_crm_attendee_record('100000004')
  end


  def search
    type, value = 'last_name', params[:ln].strip if params[:ln].present?
    type, value = 'account_name', params[:an].strip if params[:an].present?
    @results = []

    if type && value
      db = crm_connection_sql
      sql = registered_attendees_query(type, db.escape(value))

      if sql.present?
        query = db.execute(sql)
        query.each(as: :array) { |row| @results << row }
        db.close unless db.closed?
      end
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def require_assigned_crm_campaigns
    unless @event.crm_campaigns.any?
      flash.alert = "Check-In not available. Event has no assigned CRM Campaigns."
      redirect_to root_path
    end
  end

  def update_crm_attendee_record(response_code)
    @activity_id = params[:activity_id].strip unless params[:activity_id].blank?
    @sr_email = params[:sr_email].strip unless params[:sr_email].blank?
    @first_name = params[:fn].strip unless params[:fn].blank?
    @last_name = params[:ln].strip unless params[:ln].blank?
    @account_name = params[:an].strip unless params[:an].blank?

    if @activity_id
      db = crm_connection_sql
      sql = "UPDATE ActivityPointerBase SET ResponseCode = '#{response_code}' " +
        "WHERE ActivityId = '#{@activity_id}'"
      query = db.execute(sql)
      rows_updated = query.do
      db.close unless db.closed?

      @record_updated = rows_updated == 1 ? true : false
      #email_salesrep if response_code == '100000003' && @record_updated && @sr_email
    end
  end

  def email_salesrep
    NotificationMailer.customer_checked_in_email_salesrep(
      @event, @sr_email, @first_name, @last_name, @account_name
    ).deliver_later
  end

  def registered_attendees_query(type, value)
    sql = registered_attendees_base_sql_script

    @event.crm_campaigns.pluck(:code).each_with_index do |code, idx|
      sql += idx == 0 ? "\'#{code}\'" : ", \'#{code}\'"
    end
    sql += ') '
    
    if type == 'last_name'
      sql += "AND (d.LastName LIKE '#{value}%' OR a.LastName LIKE '#{value}%')" +
        "ORDER BY d.LastName, d.FirstName;"
    elsif type == 'account_name' && value.size > 2
      sql += "AND (d.ParentCustomerIdName LIKE '%#{value}%' " +
        "OR a.CompanyName LIKE '%#{value}%')" +
        "ORDER BY d.ParentCustomerIdName, d.FirstName;"
    else
      @account_length_error = true
      return false
    end

    sql
  end

  def registered_attendees_base_sql_script
    "SELECT a.ActivityId AS \"activity_id\", " +
    "e.InternalEMailAddress AS \"salesrep_email\", " +
    "a.ResponseCode AS \"response_code\", " + 
    "d.FirstName AS \"contact_first_name\", " +
    "d.LastName AS \"contact_last_name\", " +
    "d.ParentCustomerIdName AS \"contact_account_name\", " +
    "a.FirstName AS \"first_name\", a.LastName AS \"last_name\", " +
    "a.CompanyName AS \"account_name\" " +
    "FROM ActivityPointerBase AS a " +
    "JOIN CampaignBase AS b ON b.CampaignId = a.RegardingObjectId " +
    "JOIN CampaignResponseBase AS c ON c.ActivityId = a.ActivityId " +
    "LEFT JOIN ContactBase AS d ON d.ContactId = c.new_Contact " +
    "LEFT JOIN SystemUserBase AS e ON e.SystemUserId = a.OwnerId " +
    "WHERE a.ActivityTypeCode = '4401' " +
    "AND b.CodeName IN ("
  end
end