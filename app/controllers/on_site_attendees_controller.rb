class OnSiteAttendeesController < ApplicationController
  before_action :require_user
  before_action :set_event
  before_action :set_attendee, only: [:show, :edit, :update, :destroy]

  def index
    @attendees = @event.on_site_attendees.order("lower(last_name)")
  end

  def new
    @attendee = @event.on_site_attendees.new
  end

  def create
    @attendee = @event.on_site_attendees.new(on_site_attendee_params)

    if @attendee.save
      redirect_to event_on_site_attendee_path(@event, @attendee)
    else
      render 'new'
    end
  end

  def show
    @qr_code = RQRCode::QRCode.new(
      "MATMSG:TO:leads@divalsafety.com;SUB:#{@event.qr_code_email_subject};BODY:" +
      "\n\n\n______________________" +
      "\n" + @attendee.first_name + " " + @attendee.last_name +
      "\n" + @attendee.account_name +
      "#{' / ' + @attendee.account_number if @attendee.account_number}" +
      "#{"\n" + @attendee.street1 if @attendee.street1}" +
      "#{"\n" + @attendee.street2 if @attendee.street2}" +
      "#{"\n" + @attendee.city if @attendee.city}" +
      "#{"\n" if !@attendee.city && (@attendee.state || @attendee.zip)}" +
      "#{', ' if @attendee.city && @attendee.state}" +
      "#{@attendee.state if @attendee.state} " +
      "#{@attendee.zip_code if @attendee.zip_code}" +
      "#{"\n" + @attendee.email if @attendee.email}" +
      "#{"\n" + @attendee.phone if @attendee.phone}" +
      "#{"\n" + @attendee.salesrep if @attendee.salesrep};;", level: :q
    ).to_img.resize(180, 180)

    render layout: false
  end

  def edit
    @return = true if params[:return] == 'y'
  end

  def update
    if @attendee.update(on_site_attendee_params)
      redirect_to event_on_site_attendee_path(@event, @attendee)
    else
      @return = true if params[:on_site_attendee][:return] =='y'
      render 'edit'
    end
  end

  def destroy
    if @attendee.destroy
      flash.notice = "Attendee #{@attendee.first_name} " +
                     "#{@attendee.last_name} deleted."
    else
      flash.alert = "Unable to delete attendee " +
                    "#{@attendee.first_name} #{@attendee.last_name}."
    end
    redirect_to event_on_site_attendees_path(@event)
  end

  def crm_contact
    last_name = params[:last_name].strip unless params[:last_name].blank?
    account_name = params[:account_name].strip unless params[:account_name].blank?

    if last_name || account_name
      db = TinyTds::Client.new( host: '10.220.0.252', database: 'DiValSafety1_MSCRM',
        username: 'sa', password: 'CRMadmin#')
    end

    @results = []

    if last_name
      params.delete(:account_name)

      last_name = db.escape(last_name)
      query = db.execute(
        "SELECT a.FirstName, a.LastName, b.Name, b.icbcore_ExtAccountID,
          d.Line1, d.Line2, d.City, d.StateOrProvince, d.PostalCode,
          a.EMailAddress1, a.Telephone1, c.FullName
         FROM ContactBase AS a
         JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId
         JOIN SystemUserBase AS c ON a.OwnerId = c.SystemUserId
         JOIN CustomerAddressBase AS d ON a.ContactId = d.ParentId
         WHERE a.LastName = '#{last_name}'
           AND a.StateCode = '0'
           AND d.AddressNumber = '1'
         ORDER BY a.FirstName, a.LastName"
      )

      query.each(as: :array) { |row| @results << row }
      db.close unless db.closed?
    elsif account_name 
      if account_name.size > 2
        params.delete(:last_name)

        account_name = db.escape(account_name)
        query = db.execute(
          "SELECT a.FirstName, a.LastName, b.Name, b.icbcore_ExtAccountID,
            d.Line1, d.Line2, d.City, d.StateOrProvince, d.PostalCode,
            a.EMailAddress1, a.Telephone1, c.FullName
           FROM ContactBase AS a
           JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId
           JOIN SystemUserBase AS c ON a.OwnerId = c.SystemUserId
           JOIN CustomerAddressBase AS d ON a.ContactId = d.ParentId
           WHERE a.ParentCustomerIdName LIKE '%#{account_name}%'
             AND a.StateCode = '0'
             AND d.AddressNumber = '1'
           ORDER BY a.ParentCustomerIdName, a.FirstName, a.LastName"
        )

        query.each(as: :array) { |row| @results << row }
        db.close unless db.closed?
      else
        @account_length_error = true
      end
    end
  end

  def crm_account
    require 'odbc'

    unless params[:account_name].blank?
      account_name = params[:account_name].strip.upcase
    end

    @results = []
    
    if account_name
      if account_name.size > 2
        as400 = ODBC.connect('as400_fds')

        account_name = escape_single_quotes(account_name)

        sql = "SELECT cmcsnm, cmcsno FROM cusms
               WHERE UPPER(cmcsnm) LIKE '\%#{account_name}\%'
                 AND cmsusp != 'S'
                 AND cmusr1 != 'HSS'
               ORDER BY cmcsnm"

        results = as400.run(sql).fetch_all

        as400.commit
        as400.disconnect

        if results && results.any?
          results.each { |row| @results << row }
        end
      else
        @account_length_error = true
      end
    end
  end

  def crm_ship_to
    require 'odbc'
    account_number = params[:account_number] unless params[:account_number].blank?

    @results = []
    
    if account_number
      as400 = ODBC.connect('as400_fds')

      sql = "SELECT a.cmcsnm, a.cmcsno, b.sashp#, b.sashnm,
              b.sasad1, b.sasad2, b.sascty, b.sashst, b.saszip
             FROM cusms AS a
             JOIN addr AS b ON b.sacsno = a.cmcsno
             WHERE a.cmcsno = '#{account_number}'
               AND b.sasusp != 'S'
             ORDER BY CAST(b.sashp# AS INTEGER)"

      results = as400.run(sql).fetch_all

      as400.commit
      as400.disconnect

      if results && results.any?
        results.each { |row| @results << row }
      end
    end
  end

  def download
    export_folder = Rails.root.join('events', @event.id.to_s, 'attendees_export')
    export_file = Rails.root.join(export_folder, 'export.xls')

    FileUtils.mkdir(export_folder) unless Dir.exist?(export_folder)
    File.delete(export_file) if File.exist?(export_file)


    @attendees = @event.on_site_attendees.order("lower(last_name)")

    if @attendees.any?
      bold_format = Spreadsheet::Format.new :weight => :bold
      header_row = [
        'Event Name', 'Badge Type', 'Contact in CRM?', 'First Name',
        'Last Name', 'Account Name', 'Account #', 'Street 1', 'Street 2',
        'City', 'State', 'Zip Code', 'Email', 'Phone', 'Sales Rep'
      ]

      export = Spreadsheet::Workbook.new
      sheet = export.create_worksheet name: "On-Site Attendees"

      sheet.insert_row(0, header_row)
      sheet.row(0).default_format = bold_format

      sheet.column(0).width = 35
      sheet.column(1).width = 19
      sheet.column(2).width = 26
      sheet.column(3).width = 30
      sheet.column(4).width = 38
      sheet.column(5).width = 20
      sheet.column(6).width = 34
      sheet.column(7).width = 34
      sheet.column(8).width = 34
      sheet.column(9).width = 34
      sheet.column(10).width = 34
      sheet.column(11).width = 34
      sheet.column(12).width = 34
      sheet.column(13).width = 34
      sheet.column(14).width = 34

      @attendees.each do |attendee|
        attendee_row = [
          @event.name, attendee[:badge_type], attendee[:contact_in_crm],
          attendee[:first_name], attendee[:last_name], attendee[:account_name],
          attendee[:account_number], attendee[:street1], attendee[:street2],
          attendee[:city], attendee[:state], attendee[:zip_code],
          attendee[:email], attendee[:phone], attendee[:salesrep]
        ]
        
        new_row_index = sheet.last_row_index + 1
          
        sheet.insert_row(new_row_index, attendee_row)
      end

      export.write(export_file)

      send_file(export_file, type: 'application/vnd.ms-excel',
        filename: "On_Site_Attendees_#{@event.name}.xls")
    else
      flash.alert = "No on-site attendees to export for this event."
      redirect_to event_path(@event)
    end
  end

  private

  def on_site_attendee_params
    params.require(:on_site_attendee).permit(
      :first_name, :last_name, :account_name, :account_number, :street1,
      :street2, :city, :state, :zip_code, :email, :phone, :salesrep,
      :badge_type, :contact_in_crm
    )
  end

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def set_attendee
    @attendee = OnSiteAttendee.find(params[:id]) if params[:id]
  end

  def escape_single_quotes(string)
    string.chars.map { |char| char == "\'" ? "\'\'" : char }.join('')
  end
end