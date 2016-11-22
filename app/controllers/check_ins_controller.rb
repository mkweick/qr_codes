class CheckInsController < ApplicationController
  before_action :require_user
  before_action :set_event
  before_action :require_active_event
  before_action :require_assigned_crm_campaigns

  def new; end

  def attended
    @activity_id = params[:activity_id].strip unless params[:activity_id].blank?
    @sr_email = params[:sr_email].strip unless params[:sr_email].blank?
    @first_name = params[:fn].strip unless params[:fn].blank?
    @last_name = params[:ln].strip unless params[:ln].blank?
    @account_name = params[:an].strip unless params[:an].blank?

    if @activity_id
      db = TinyTds::Client.new(
        host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
        username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
      )

      sql = "UPDATE ActivityPointerBase " +
        "SET ResponseCode = '100000003' " +
        "WHERE ActivityId = '#{@activity_id}';"

      query = db.execute(sql)
      affected_rows = query.do
      db.close unless db.closed?

      @attended = affected_rows == 1 ? true : false

      # Uncomment to send salesrep email when customer checks in
      # if @attended && @sr_email
      #   NotificationMailer.customer_checked_in_email_salesrep(
      #     @event, @sr_email, @first_name, @last_name, @account_name
      #   ).deliver_later
      # end
    end
  end

  def not_attended
    @activity_id = params[:activity_id].strip unless params[:activity_id].blank?
    @sr_email = params[:sr_email].strip unless params[:sr_email].blank?
    @first_name = params[:fn].strip unless params[:fn].blank?
    @last_name = params[:ln].strip unless params[:ln].blank?
    @account_name = params[:an].strip unless params[:an].blank?

    if @activity_id
      db = TinyTds::Client.new(
        host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
        username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
      )

      sql = "UPDATE ActivityPointerBase " +
        "SET ResponseCode = '100000004' " +
        "WHERE ActivityId = '#{@activity_id}';"

      query = db.execute(sql)
      affected_rows = query.do
      db.close unless db.closed?

      @not_attended = affected_rows == 1 ? true : false
    end
  end


  def search
    first_name = params[:first_name].strip unless params[:first_name].blank?
    last_name = params[:last_name].strip unless params[:last_name].blank?
    account_name = params[:account_name].strip unless params[:account_name].blank?
    @results = []

    if first_name || last_name || account_name
      db = TinyTds::Client.new(
        host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
        username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
      )

      sql = registered_attendees_base_sql_script
    end

    if first_name
      first_name = db.escape(first_name)
      sql += "AND (d.FirstName LIKE '#{first_name}%' OR a.FirstName LIKE '#{first_name}%')"
      sql += "ORDER BY d.FirstName, d.LastName;"
    elsif last_name
      last_name = db.escape(last_name)
      sql += "AND (d.LastName LIKE '#{last_name}%' OR a.LastName LIKE '#{last_name}%')"
      sql += "ORDER BY d.LastName, d.FirstName;"
    elsif account_name
      if account_name.size > 2
        account_name = db.escape(account_name)
        sql += "AND (d.ParentCustomerIdName LIKE '%#{account_name}%' OR a.CompanyName LIKE '%#{account_name}%')"
        sql += "ORDER BY d.ParentCustomerIdName, d.FirstName;"
      else
        @account_length_error = true
      end
    end

    if db
      query = db.execute(sql)
      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?
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

  def registered_attendees_base_sql_script
    base_sql_statement = "SELECT a.ActivityId AS \"activity_id\", " +
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

    @event.crm_campaigns.pluck(:code).each_with_index do |code, idx|
      base_sql_statement += idx == 0 ? "\'#{code}\'" : ", \'#{code}\'"
    end
    
    base_sql_statement += ') '
    base_sql_statement
  end
end