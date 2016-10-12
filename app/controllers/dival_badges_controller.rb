class DivalBadgesController < ApplicationController
  before_action :require_user

  def new; end

  def print
    @first_name = params[:first_name].strip if params[:first_name].present?
    @last_name = params[:last_name].strip if params[:last_name].present?
    @account_name = params[:account_name].strip if params[:account_name].present?
    title = params[:title].strip if params[:title].present?
    street1 = params[:street1].strip if params[:street1].present?
    street2 = params[:street2].strip if params[:street2].present?
    city = params[:city].strip if params[:city].present?
    state = params[:state].strip if params[:state].present?
    zip_code = params[:zip_code].strip if params[:zip_code].present?
    email = params[:email].strip if params[:email].present?
    phone = params[:phone].strip if params[:phone].present?

    if @first_name && @last_name && @account_name && title &&
       street1 && city && state && zip_code && email && phone

      # Labels are 2-3/7" wide and 2-7/8" cut length
      # 180 x 180 = 1.25"  /  220 x 220 = 1.50"
      @qr_code = RQRCode::QRCode.new(
        "MATMSG:TO:;SUB:DIVAL SALES REP REQUEST;BODY:" +
        "\n\n\n______________________" +
        "\n" + @first_name + " " + @last_name +
        "\n" + title +
        "#{"\n" + email if email}" +
        "#{"\n" + phone if phone}" +
        "\n\n" + @account_name +
        "#{"\n" + street1 if street1}" +
        "#{"\n" + street2 if street2}" +
        "#{"\n" + city if city}" +
        "#{"\n" if !city && (state || zip_code)}" +
        "#{', ' if city && state}" + "#{state if state} " +
        "#{zip_code if zip_code};;", level: :q
      ).to_img.resize(180, 180)

      render layout: false
    else
      flash.now.alert = "Missing required information."
      render 'new'
    end
  end

  def crm_dival_employee
    last_name = params[:last_name].strip unless params[:last_name].blank?
    @results = []

    if last_name
      db = TinyTds::Client.new(
        host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
        username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
      )

      last_name = db.escape(last_name)
      query = db.execute(
        "SELECT a.FirstName, a.LastName, 'DiVal Safety Equipment' AS \"Name\",
          c.Line1, c.Line2, c.City, c.StateOrProvince, c.PostalCode,
          a.EMailAddress1, a.Telephone1
         FROM ContactBase AS a
         JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId
         JOIN CustomerAddressBase AS c ON a.ContactId = c.ParentId
         WHERE a.LastName = '#{last_name}'
           AND a.StateCode = '0'
           AND b.icbcore_ExtAccountID = '01-101673'
           AND c.AddressNumber = '1'
         ORDER BY a.FirstName, a.LastName"
      )

      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?
    end
  end
end