class CheckInsController < ApplicationController
  before_action :require_user
  before_action :set_event

  def new; end

  def attended
    @activity_id = params[:activity_id].strip unless params[:activity_id].blank?
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
    end
  end

  def not_attended
    @activity_id = params[:activity_id].strip unless params[:activity_id].blank?
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
    end

    if first_name
      params.delete(:last_name)
      params.delete(:account_name)
      first_name = db.escape(first_name)

      sql = "SELECT a.ActivityId AS \"activity_id\", " +
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
        "WHERE a.ActivityTypeCode = '4401' " +
          "AND a.StateCode = '0' " +
          "AND a.StatusCode = '1' " +
          "AND b.CodeName IN ("

      @event.crm_campaigns.pluck(:code).each_with_index do |code, idx|
        idx == 0 ? (sql += "\'#{code}\'") : (sql += ", \'#{code}\'")
      end
      sql += ") AND (d.FirstName LIKE '#{first_name}%' OR a.FirstName LIKE '#{first_name}%')"
      sql += "ORDER BY d.FirstName, d.LastName;"

      query = db.execute(sql)
      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?

    elsif last_name
      params.delete(:first_name)
      params.delete(:account_name)
      last_name = db.escape(last_name)

      sql = "SELECT a.ActivityId AS \"activity_id\", " +
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
        "WHERE a.ActivityTypeCode = '4401' " +
          "AND a.StateCode = '0' " +
          "AND a.StatusCode = '1' " +
          "AND b.CodeName IN ("
          
      @event.crm_campaigns.pluck(:code).each_with_index do |code, idx|
        idx == 0 ? (sql += "\'#{code}\'") : (sql += ", \'#{code}\'")
      end
      sql += ") AND (d.LastName LIKE '#{last_name}%' OR a.LastName LIKE '#{last_name}%')"
      sql += "ORDER BY d.LastName, d.FirstName;"

      query = db.execute(sql)
      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?

    elsif account_name
      if account_name.size > 2
        params.delete(:first_name)
        params.delete(:last_name)
        account_name = db.escape(account_name)

        sql = "SELECT a.ActivityId AS \"activity_id\", " +
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
          "WHERE a.ActivityTypeCode = '4401' " +
            "AND a.StateCode = '0' " +
            "AND a.StatusCode = '1' " +
            "AND b.CodeName IN ("
          
        @event.crm_campaigns.pluck(:code).each_with_index do |code, idx|
          idx == 0 ? (sql += "\'#{code}\'") : (sql += ", \'#{code}\'")
        end
        sql += ") AND (d.ParentCustomerIdName LIKE '%#{account_name}%' OR a.CompanyName LIKE '%#{account_name}%')"
        sql += "ORDER BY d.ParentCustomerIdName, d.FirstName;"

        query = db.execute(sql)
        query.each(as: :array) { |row| @results << row }
        db.close unless db.closed?
      else
        @account_length_error = true
      end
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end
end