class DivalBadgesController < ApplicationController
  before_action :require_user

  def new; end

  def print
    @employee = employee_params

    if required_fields_present? 
      qr_code = generate_qr_code  
      @qr_code = qr_code.to_img.resize(165, 165)
      render layout: false
    else
      flash.now.alert = "Missing required information."
      render 'new'
    end
  end

  def crm_dival_employee
    type, value = 'first', params[:fn].strip if params[:fn].present?
    type, value = 'last', params[:ln].strip if params[:ln].present?
    @results = []

    if type && value
      db = crm_connection_sql
      sql = crm_dival_employees_query(type, db.escape(value))
      query = db.execute(sql)
      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?
    end
  end

  private

  def employee_params
    info = {}
    info[:first_name] = params[:first_name].strip if params[:first_name].present?
    info[:last_name] = params[:last_name].strip if params[:last_name].present?
    info[:title] = params[:title].strip if params[:title].present?
    info[:street1] = params[:street1].strip if params[:street1].present?
    info[:street2] = params[:street2].strip if params[:street2].present?
    info[:city] = params[:city].strip if params[:city].present?
    info[:state] = params[:state].strip if params[:state].present?
    info[:zip_code] = params[:zip_code].strip if params[:zip_code].present?
    info[:email] = params[:email].strip if params[:email].present?
    info[:phone] = params[:phone].strip if params[:phone].present?
    info
  end

  def required_fields_present?
    @employee[:first_name] && @employee[:last_name] && @employee[:street1] && 
    @employee[:city] &&  @employee[:state] && @employee[:zip_code] && 
    @employee[:email] && @employee[:phone]
  end

  def generate_qr_code
    RQRCode::QRCode.new(
      "MATMSG:TO:;SUB:DIVAL SALES REP REQUEST;BODY:" +
      "\n\n\n______________________" +
      "\n" + "N: " + @employee[:first_name] + " " + @employee[:last_name] +
      "\n" + "T: " + "#{@employee[:title] if @employee[:title]}" +
      "\n" + "E: " + "#{@employee[:email] if @employee[:email]}" +
      "\n" + "P: " + "#{@employee[:phone] if @employee[:phone]}" +
      "\n\n" + "DiVal Safety Equipment" +
      "\n" + "AD1: " + "#{@employee[:street1] if @employee[:street1]}" +
      "\n" + "AD2: " + "#{@employee[:street2] if @employee[:street2]}" +
      "\n" + "CSZ: " + "#{@employee[:city] if @employee[:city]}" +
        "#{', ' if @employee[:city] && @employee[:state]}" +
        "#{@employee[:state] if @employee[:state]} " +
        "#{@employee[:zip_code] if @employee[:zip_code]};;",
      level: :l
    )
  end

  def crm_dival_employees_query(type, value)
    sql = "SELECT a.FirstName, a.LastName, c.Line1, " +
    "c.Line2, c.City, c.StateOrProvince, c.PostalCode, " +
    "a.EMailAddress1, a.Telephone1 " +
    "FROM ContactBase AS a " +
    "JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId " +
    "JOIN CustomerAddressBase AS c ON a.ContactId = c.ParentId " +
    "WHERE a.StateCode = '0' " +
    "AND b.icbcore_ExtAccountID = '01-101673' " +
    "AND c.AddressNumber = '1' "

    sql += "AND #{type == 'first' ? 'a.FirstName' : 'a.LastName'} LIKE '#{value}%' "
    sql += "ORDER BY a.FirstName, a.LastName"
    sql
  end
end
