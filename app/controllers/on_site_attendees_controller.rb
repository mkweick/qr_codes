class OnSiteAttendeesController < ApplicationController
  before_action :require_user
  before_action :set_event
  before_action :set_attendee, only: [:show, :edit, :update, :destroy]

  def index

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
    ).to_img.resize(375, 375)

    render layout: false
  end

  def edit; end

  def update
    if @attendee.update(on_site_attendee_params)
      redirect_to event_on_site_attendee_path(@event, @attendee)
    else
      @attendee.reload
      render 'edit'
    end
  end

  def destroy

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

  def generate
    contact_id = params[:contact_id] if params[:contact_id]

    if contact_id
      db = TinyTds::Client.new( host: '10.220.0.252', database: 'DiValSafety1_MSCRM',
        username: 'sa', password: 'CRMadmin#')

      query = db.execute(
        "SELECT a.FullName, b.Name AS \"AccountName\",
          b.icbcore_ExtAccountID AS \"AccountNumber\",
          c.FullName AS \"SalesRep\", a.EMailAddress1  AS \"Email\",
          a.Telephone1  AS \"Phone\", d.Line1 AS \"Street1\",
          d.Line2 AS \"Street2\", d.City, d.StateOrProvince AS \"State\",
          d.PostalCode AS \"Zip\", 'VENDOR: ' AS \"EmailSubject\"
         FROM ContactBase AS a
         JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId
         JOIN SystemUserBase AS c ON a.OwnerId = c.SystemUserId
         JOIN CustomerAddressBase AS d ON a.ContactId = d.ParentId
         WHERE a.ContactId = '#{contact_id}'
           AND d.AddressNumber = '1'"
      )

      contact = query.each(as: :array).first
      db.close unless db.closed?

      if contact
        @qr = RQRCode::QRCode.new("MATMSG:TO:leads@divalsafety.com;SUB:#{contact[11]};BODY:" +
          "\n______________________" +
          "#{"\n" + contact[0]}" +
          "#{"\n" + contact[1]}#{' / ' + contact[2] if contact[2]}" +
          "#{"\n" + contact[6] if contact[6]}" +
          "#{"\n" + contact[7] if contact[7]}" +
          "#{"\n" + contact[8] if contact[8]}" +
          "#{"\n" if !contact[8] && (contact[9] || contact[10])}" +
          "#{', ' if contact[8] && contact[9]}" +
          "#{contact[9] if contact[9]} #{contact[10]  if contact[10]}" +
          "#{"\n" + 'E: ' + contact[4] if contact[4]}" +
          "#{"\n" + 'P: ' + contact[5] if contact[5]}" +
          "#{"\n" + contact[3] if contact[3]};;", level: :q).to_img.resize(375, 375)
      else
        flash.alert = "No contact found."
        redirect_to crm_contact_event_path(@event)
      end
    else
      flash.alert = "Contact ID missing."
      redirect_to crm_contact_event_path(@event)
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