class OnSiteAttendeesController < ApplicationController
  before_action :require_user
  before_action :set_event
  before_action :set_on_site_attendee, only: [:edit, :update, :destroy]

  def new

  end

  def create

  end

  def edit

  end

  def update

  end

  def destroy

  end

  def crm_contact
    last_name = params[:last_name].strip unless params[:last_name].blank?
    account_name = params[:account_name].strip unless params[:account_name].blank?

    if last_name || account_name
      db = TinyTds::Client.new( host: '10.220.0.252', database: 'DiValSafety1_MSCRM',
        username: 'sa', password: 'CRMadmin#')

      @results = []
    end

    if last_name
      params.delete(:account_name)

      last_name = db.escape(last_name)
      query = db.execute(
        "SELECT a.ContactId, a.FullName, a.ParentCustomerIdName, b.FullName AS \"SalesRep\"
         FROM ContactBase AS a
         JOIN SystemUserBase AS b ON a.OwnerId = b.SystemUserId
         WHERE a.LastName = '#{last_name}'
           AND a.StateCode = '0'
         ORDER BY a.FullName"
      )

      query.each(symbolize_keys: true) { |row| @results << row }
      db.close unless db.closed?
    elsif account_name 
      if account_name.size > 2
        params.delete(:last_name)

        account_name = db.escape(account_name)
        query = db.execute(
          "SELECT a.ContactId, a.FullName, a.ParentCustomerIdName, b.FullName AS \"SalesRep\"
           FROM ContactBase AS a
           JOIN SystemUserBase AS b ON a.OwnerId = b.SystemUserId
           WHERE a.ParentCustomerIdName LIKE '%#{account_name}%'
             AND a.StateCode = '0'
           ORDER BY a.ParentCustomerIdName, a.FullName"
        )

        query.each(symbolize_keys: true) { |row| @results << row }
        db.close unless db.closed?
      else
        flash.now.alert = "Minimum of 3 characters required for account search."
      end
    end
  end

  def crm_account

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

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def set_on_site_attendee
    @attendee = OnSiteAttendee.find(params[:id]) if params[:id]
  end
end