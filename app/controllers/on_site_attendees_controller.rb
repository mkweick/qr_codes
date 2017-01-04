class OnSiteAttendeesController < ApplicationController
  before_action :require_user
  before_action :set_event
  before_action :require_active_event
  before_action :set_attendee, only: [:show, :edit, :update, :destroy]

  def index
    @attendees = @event.on_site_attendees.order("lower(last_name)")
    @event_has_campaigns = @event.crm_campaigns.any?
  end

  def new
    @attendee = @event.on_site_attendees.new
    @event_has_campaigns = @event.crm_campaigns.any?
  end

  def create
    @attendee = @event.on_site_attendees.new(on_site_attendee_params)
    contact_id = params[:contact_id]
    activity = {}

    if @attendee.save
      if @attendee.badge_type == 'NEW'
        begin
          if @attendee.contact_in_crm && contact_id.present?
            activity = create_crm_cr_existing_customer(contact_id) || {}
          else
            activity = create_crm_cr_new_customer || {}
          end
        rescue
          log_contact_error_msg(contact_id)
        end

        @attendee.update(activity_id: activity['id']) if activity.any?
      end
      
      redirect_to event_on_site_attendee_path(@event, @attendee)
    else
      @event_has_campaigns = @event.crm_campaigns.any?
      render 'new'
    end
  end

  def show
    qr_code = generate_qr_code
    @qr_code = qr_code.to_img.resize(165, 165)
    render layout: false
  end

  def edit
    @return = true if params[:return] == 'y'
  end

  def update
    if @attendee.update(on_site_attendee_params)
      @update_fields = @attendee.previous_changes.except('updated_at')

      if activity_id_and_updates_and_new_contact?
        begin
          update_crm_cr_new_customer
        rescue
          log_update_new_contact_error_msg
        end
      end

      redirect_to event_on_site_attendee_path(@event, @attendee)
    else
      @return = true if params[:on_site_attendee][:return] =='y'
      render 'edit'
    end
  end

  def destroy
    if @attendee.destroy
      if @attendee.activity_id
        begin
          delete_crm_cr
        rescue
          log_delete_crm_cr_error_msg
        end
      end
      attendee_delete_msg
    else
      attendee_delete_error_msg
    end

    redirect_to event_on_site_attendees_path(@event)
  end

  def crm_contact
    type, value = 'last_name', params[:ln].strip if params[:ln].present?
    type, value = 'account_name', params[:an].strip if params[:an].present?
    @results = []

    if type && value
      db = crm_connection_sql
      sql = crm_contacts_query(type, db.escape(value))

      if sql.present?
        query = db.execute(sql)
        query.each(as: :array) { |row| @results << row }
        db.close unless db.closed?
      end
    end
  end

  def as400_account
    account_name = params[:account_name].strip if params[:account_name].present?
    @results = []
    
    if account_name
      if account_name.size > 2
        results = execute_as400_query(account_script(account_name)) || []
        results.each { |row| @results << row } if results.any?
      else
        @account_length_error = true
      end
    end
  end

  def as400_ship_to
    @account_name = params[:account_name] || nil
    account_number = params[:account_number] || nil
    @results = []

    if account_number
      results = execute_as400_query(ship_to_script(account_number)) || []
      results.each { |row| @results << row } if results.any?
    end
  end

  def download
    attendees = @event.on_site_attendees.order(:created_at)

    if attendees.any?
      prep_attendee_export_dir
      export = Spreadsheet::Workbook.new
      sheet = export.create_worksheet name: "On-Site Attendees"
      set_attendee_export_styling(sheet)

      attendees.each do |row|
        attendee_row = format_attendee_data(row)
        new_row_index = sheet.last_row_index + 1
        sheet.insert_row(new_row_index, attendee_row)
      end

      export.write(attendee_export_file)
      send_attendee_export_file
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

  def generate_qr_code
    RQRCode::QRCode.new(
      "MATMSG:TO:leads@divalsafety.com;SUB:" +
      "#{@event.qr_code_email_subject};BODY:" +
      "\n\n\n______________________" +
      "\n" + "N: " + @attendee.first_name + " " + @attendee.last_name +
      "\n" + "C: " + @attendee.account_name +
        "#{' / ' + @attendee.account_number if @attendee.account_number}" + 
      "\n" + "AD1: " + "#{@attendee.street1 if @attendee.street1}" +
      "\n" + "AD2: " + "#{@attendee.street2 if @attendee.street2}" +
      "\n" + "CSZ: " + "#{@attendee.city if @attendee.city}" +
        "#{', ' if @attendee.city && @attendee.state}" +
        "#{@attendee.state if @attendee.state} " +
        "#{@attendee.zip_code if @attendee.zip_code}" +
      "\n" + "E: " + "#{@attendee.email if @attendee.email}" +
      "\n" + "P: " + "#{@attendee.phone if @attendee.phone}" +
      "\n" + "SR: " + "#{@attendee.salesrep if @attendee.salesrep};;",
      level: :l
    )
  end

  def create_crm_cr_existing_customer(contact_id)
    campaign_id = find_event_today
    return false unless campaign_id
    contact = query_contact_script(contact_id)

    create_with_existing_in_crm(contact, campaign_id)
  end

  def query_contact_script(id)
    sql = "SELECT ContactId, OwnerId, ParentCustomerId FROM ContactBase " +
      "WHERE ContactId = '#{id}'"
    db = crm_connection_sql
    query = db.execute(sql)
    contact = query.each(:symbolize_keys => true).first
    db.close unless db.closed?
    contact
  end

  def create_with_existing_in_crm(contact, campaign_id)
    regardingobject = DynamicsCRM::XML::EntityReference.new('campaign', campaign_id)
    owner = DynamicsCRM::XML::EntityReference.new('systemuser', contact[:OwnerId])
    account = DynamicsCRM::XML::EntityReference.new('account', contact[:ParentCustomerId])
    crm_contact = DynamicsCRM::XML::EntityReference.new('contact', contact[:ContactId])

    client = crm_connection_soap
    entity = DynamicsCRM::XML::Entity.new('campaignresponse')
    entity.attributes = DynamicsCRM::XML::Attributes.new(
      regardingobjectid: regardingobject, ownerid: owner, subject: '.',
      new_account: account, new_contact: crm_contact
    )
    xml = entity_to_xml_with_attended(entity)
    client.create(xml)
  end

  def create_crm_cr_new_customer
    campaign_id = find_event_today
    return false unless campaign_id
    owner_id = assign_salesrep

    create_with_new_in_crm(owner_id, campaign_id)
  end

  def log_contact_error_msg(contact_id)
    logger.error(
      "Issue creating CRM Campaign Response for customer " +
      "#{'ContactId: ' + contact_id + ' - ' if contact_id}" +
      "#{@attendee.first_name} #{@attendee.last_name} " +
      "from #{@attendee.account_name}" +
      "#{' / ' + @attendee.account_number if @attendee.account_number}."
    )
  end

  def activity_id_and_updates_and_new_contact?
    @update_fields.any? && @attendee.activity_id && !@attendee.contact_in_crm
  end

  def update_crm_cr_new_customer
    if @update_fields['salesrep']
      campaign_id = query_campaign_id_for_campaign_response
      owner_id = assign_salesrep

      if delete_crm_cr
        activity_id = create_with_new_in_crm(owner_id, campaign_id)['id'] || nil
        @attendee.update(activity_id: activity_id) if activity_id
      end
    else
      client = crm_connection_soap
      client.update('campaignresponse', @attendee.activity_id, changed_fields)
    end
  end

  def log_update_new_contact_error_msg
    logger.error(
      "Issue updating CRM Campaign Response with ActivityId #{@attendee.activity_id}"
    )
  end

  def create_with_new_in_crm(owner_id, campaign_id)
    regardingobject = DynamicsCRM::XML::EntityReference.new('campaign', campaign_id)
    owner = DynamicsCRM::XML::EntityReference.new('systemuser', owner_id)

    client = crm_connection_soap
    entity = DynamicsCRM::XML::Entity.new('campaignresponse')
    entity.attributes = DynamicsCRM::XML::Attributes.new(
      regardingobjectid: regardingobject, ownerid: owner, subject: '.',
      companyname: @attendee.account_name, firstname: @attendee.first_name,
      lastname: @attendee.last_name, new_street_1: @attendee.street1,
      new_street2: @attendee.street2, new_city: @attendee.city,
      new_stateprovince: @attendee.state, new_zippostalcode: @attendee.zip_code,
      emailaddress: @attendee.email, telephone: @attendee.phone
    )
    xml = entity_to_xml_with_attended(entity)
    client.create(xml)
  end

  def query_campaign_id_for_campaign_response
    sql = "SELECT b.CampaignId FROM ActivityPointerBase AS a " +
      "JOIN CampaignBase AS b ON b.CampaignId = a.RegardingObjectId " +
      "WHERE a.ActivityId = '#{@attendee.activity_id}'"
    db = crm_connection_sql
    query = db.execute(sql)
    query.each(:symbolize_keys => true).first[:CampaignId]
  end

  def delete_crm_cr
    client = crm_connection_soap
    client.delete('campaignresponse', @attendee.activity_id)
  end

  def log_delete_crm_cr_error_msg
    logger.error(
      "Issue deleteing Campaign Response from CRM with ActivityId '#{@attendee.activity_id}'"
    )
  end

  def attendee_delete_msg
    flash.notice = "Attendee #{@attendee.first_name} " +
      "#{@attendee.last_name} deleted."
  end

  def attendee_delete_error_msg
    flash.alert = "Unable to delete attendee #{@attendee.first_name} " +
      "#{@attendee.last_name}."
  end

  def changed_fields
    fields = {}
    fields[:companyname] = @attendee.account_name if @update_fields['account_name']
    fields[:firstname] = @attendee.first_name if @update_fields['first_name']
    fields[:lastname] = @attendee.last_name if @update_fields['last_name']
    fields[:new_street_1] = @attendee.street1 if @update_fields['street1']
    fields[:new_street2] = @attendee.street2 if @update_fields['street2']
    fields[:new_city] = @attendee.city if @update_fields['city']
    fields[:new_stateprovince] = @attendee.state if @update_fields['state']
    fields[:new_zippostalcode] = @attendee.zip_code if @update_fields['zip_code']
    fields[:emailaddress] = @attendee.email if @update_fields['email']
    fields[:telephone] = @attendee.phone if @update_fields['phone']
    fields
  end

  def crm_contacts_query(type, value)
    sql = "SELECT a.FirstName, a.LastName, b.Name, b.icbcore_ExtAccountID, " +
      "d.Line1, d.Line2, d.City, d.StateOrProvince, d.PostalCode, " +
      "a.EMailAddress1, a.Telephone1, c.FullName, a.ContactId " +
      "FROM ContactBase AS a " +
      "JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId " +
      "JOIN SystemUserBase AS c ON a.OwnerId = c.SystemUserId " +
      "JOIN CustomerAddressBase AS d ON a.ContactId = d.ParentId " +
      "WHERE a.StateCode = '0' " +
      "AND d.AddressNumber = '1' "

    if type == 'last_name'
      sql += "AND a.LastName = '#{value}' ORDER BY a.FirstName, a.LastName"
    elsif type == 'account_name' && value.size > 2
      sql += "AND a.ParentCustomerIdName LIKE '%#{value}%' " +
        "ORDER BY a.ParentCustomerIdName, a.FirstName, a.LastName"
    else
      @account_length_error = true
      return false
    end

    sql
  end

  def find_event_today
    event = @event.crm_campaigns.where(
      "? BETWEEN event_start_date AND event_end_date", Date.today
      #"? BETWEEN event_start_date AND event_end_date", Date.new(2016,12,15)
    ).first

    event ? event.campaign_id : false
  end

  def assign_salesrep
    salesrep = {}

    if @attendee.salesrep
      db = crm_connection_sql

      split_name = @attendee.salesrep.split(' ', 2)
      first_name = db.escape(split_name[0])
      last_name = db.escape(split_name[1]) if split_name[1]

      sql = "SELECT SystemUserId FROM SystemUserBase " +
        "WHERE FirstName LIKE '%#{first_name}%' " +
        last_name_sql_condition(last_name, first_name)

      query = db.execute(sql)
      results = query.each(:symbolize_keys => true)
      db.close unless db.closed?
      salesrep = results.first if results.any?
    end
    
    # Assign to Jess Spencer if salesrep not found/provided
    salesrep[:SystemUserId] || '3A543400-4C6A-E211-A54A-00265585B80D'
  end

  def last_name_sql_condition(last_name, first_name)
    if last_name
      "AND LastName LIKE '%#{last_name}%'"
    else
      "OR LastName LIKE '%#{first_name}%'"
    end
  end

  def entity_to_xml_with_attended(entity)
    xml = entity.to_xml
    xml = xml.insert(xml.index("\n</a:Attributes>"), attended_xml)
  end

  def attended_xml
    DynamicsCRM::XML::Attributes.new(responsecode: 10000003).build_xml(
      'responsecode', 100000003, 'OptionSetValue'
    )
  end

  def account_script(account_name)
    account_name = escape_single_quotes(account_name)

    "SELECT cmcsnm, cmcsno FROM cusms " +
    "WHERE UPPER(cmcsnm) LIKE '\%#{account_name.upcase}\%' " +
    "AND cmsusp != 'S' " +
    "AND cmusr1 != 'HSS' " +
    "ORDER BY cmcsnm"
  end

  def ship_to_script(account_number)
    "SELECT a.cmcsnm, '01-' || a.cmcsno, b.sashp#, b.sashnm, " +
    "b.sasad1, b.sasad2, b.sascty, b.sashst, b.saszip " +
    "FROM cusms AS a " +
    "JOIN addr AS b ON b.sacsno = a.cmcsno " +
    "WHERE a.cmcsno = '#{account_number}' " +
    "AND b.sasusp != 'S' " +
    "ORDER BY CAST(b.sashp# AS INTEGER)"
  end

  def set_attendee_export_styling(sheet)
    sheet.insert_row(0, export_header_row)
    sheet.row(0).default_format = Spreadsheet::Format.new :weight => :bold
    sheet.column(0).width = 28
    sheet.column(1).width = 15
    sheet.column(2).width = 15
    sheet.column(3).width = 14
    sheet.column(4).width = 26
    sheet.column(5).width = 19
    sheet.column(6).width = 21
    sheet.column(7).width = 32
    sheet.column(8).width = 13
    sheet.column(9).width = 25
    sheet.column(10).width = 26
    sheet.column(11).width = 19
    sheet.column(12).width = 8
    sheet.column(13).width = 13
    sheet.column(14).width = 34
    sheet.column(15).width = 20
    sheet.column(16).width = 19
  end

  def export_header_row
    ['Event Name', 'Created Date', 'Created Time', 'Badge Type',
     'Created from CRM Contact?', 'First Name', 'Last Name',
     'Account Name', 'Account #', 'Street 1', 'Street 2',
     'City', 'State', 'Zip Code', 'Email', 'Phone', 'Sales Rep']
  end

  def format_attendee_data(attendee)
    created_date = attendee[:created_at].strftime("%m/%d/%Y")
    created_time = attendee[:created_at].strftime("%l:%M%p")
    created_from_crm = attendee[:contact_in_crm] ? "TRUE" : "FALSE"

    [@event.name, created_date, created_time, attendee[:badge_type],
     created_from_crm, attendee[:first_name], attendee[:last_name],
     attendee[:account_name], attendee[:account_number],
     attendee[:street1], attendee[:street2], attendee[:city],
     attendee[:state], attendee[:zip_code], attendee[:email],
     attendee[:phone], attendee[:salesrep]]
  end

  def prep_attendee_export_dir
    make_attendee_export_dir unless Dir.exist?(attendee_export_dir)
    delete_attendee_export_file if File.exist?(attendee_export_file)
  end

  def attendee_export_dir
    Rails.root.join('events', @event.id.to_s, 'attendees_export')
  end

  def attendee_export_file
    Rails.root.join(attendee_export_dir, 'export.xls')
  end

  def make_attendee_export_dir
    FileUtils.mkdir(attendee_export_dir)
  end

  def delete_attendee_export_file
    FileUtils.remove_file(attendee_export_file)
  end

  def send_attendee_export_file
    send_file(attendee_export_file, type: 'application/vnd.ms-excel',
      filename: "On_Site_Attendees_#{@event.name}.xls")
  end

  def execute_as400_query(sql)
    require 'odbc'
    as400 = ODBC.connect('as400_fds')
    results = as400.run(sql).fetch_all
    as400.commit
    as400.disconnect
    results
  end

  def crm_connection_soap
    client = DynamicsCRM::Client.new({
      hostname: ENV["CRM_APP_HOST"],
      login_url: ENV["CRM_APP_LOGIN_URL"]
    })
    client.authenticate(ENV["CRM_APP_UN"], ENV["CRM_APP_PW"])
    client
  end

  def escape_single_quotes(string)
    string.chars.map { |char| char == "\'" ? "\'\'" : char }.join('')
  end
end
