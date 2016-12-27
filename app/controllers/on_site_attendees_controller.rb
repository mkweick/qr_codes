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

    if @attendee.save
      if @attendee.badge_type == 'NEW'
        if @attendee.contact_in_crm
          if contact_id
            begin
              @activity = create_crm_campaign_response_existing_customer(contact_id)
            rescue
              logger.error(
                "CRM Event Registration not created for existing CRM " +
                "Contact #{@attendee.first_name} #{@attendee.last_name} " +
                "from #{@attendee.account_name} / #{@attendee.account_number}."
              )
            end
          else
            logger.error(
              "Missing ContactId. CRM Event Registration not created for " +
              "existing CRM Contact #{@attendee.first_name} #{@attendee.last_name} " +
              "from #{@attendee.account_name} / #{@attendee.account_number}."
            )
          end
        else
          begin
            @activity = create_crm_campaign_response_new_customer
          rescue
            logger.error("Issue creating CRM Campaign Response for new " +
              "customer #{@attendee.first_name} #{@attendee.last_name} " +
              "from #{@attendee.account_name}."
            )
          end
        end
      end
      
      if @activity && @activity.any?
        @attendee.update(activity_id: @activity['id'])
      end

      redirect_to event_on_site_attendee_path(@event, @attendee)
    else
      @event_has_campaigns = @event.crm_campaigns.any?
      render 'new'
    end
  end

  def show
    # Labels are 2-3/7" wide and 2-7/8" cut length
    # 180 x 180 = 1.25" /  220 x 220 = 1.50"
    @qr_code = RQRCode::QRCode.new(
      "MATMSG:TO:leads@divalsafety.com;SUB:#{@event.qr_code_email_subject};BODY:" +
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
    ).to_img.resize(165, 165)

    render layout: false
  end

  def edit
    @return = true if params[:return] == 'y'
  end

  def update
    if @attendee.update(on_site_attendee_params)
      @update_fields = @attendee.previous_changes.except('updated_at')

      if @update_fields.any? && @attendee.activity_id && !@attendee.contact_in_crm
        begin
          update_crm_campaign_response_new_customer
        rescue
          logger.error("Issue updating CRM Campaign Response " +
            "with ActivityId #{@attendee.activity_id} "
          )
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
          if delete_crm_campaign_response
            logger.info("Campaign Response deleted with ActivityId " +
               "'#{@attendee.activity_id}'")
          end
        rescue
          logger.error("Issue deleteing Campaign Response from CRM with " +
            "ActivityId '#{@attendee.activity_id}'")
        end
      end

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
    @results = []

    if last_name || (account_name && account_name.size > 2)
      db = TinyTds::Client.new(
        host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
        username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
      )

      sql = crm_contacts_base_sql_query
    end

    if last_name
      last_name = db.escape(last_name)
      sql += "AND a.LastName = '#{last_name}' "
      sql += "ORDER BY a.FirstName, a.LastName"
    elsif account_name
      if account_name.size > 2
        account_name = db.escape(account_name)
        sql += "AND a.ParentCustomerIdName LIKE '%#{account_name}%' "
        sql += "ORDER BY a.ParentCustomerIdName, a.FirstName, a.LastName"
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

  def as400_account
    require 'odbc'

    account_name = params[:account_name].strip unless params[:account_name].blank?
    @results = []
    
    if account_name
      if account_name.size > 2
        as400 = ODBC.connect('as400_fds')

        account_name = escape_single_quotes(account_name)

        sql = "SELECT cmcsnm, cmcsno FROM cusms " +
          "WHERE UPPER(cmcsnm) LIKE '\%#{account_name.upcase}\%' " +
          "AND cmsusp != 'S' " +
          "AND cmusr1 != 'HSS' " +
          "ORDER BY cmcsnm"

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

  def as400_ship_to
    require 'odbc'
    @account_name = params[:account_name] unless params[:account_name].blank?
    account_number = params[:account_number] unless params[:account_number].blank?

    @results = []
    
    if account_number
      as400 = ODBC.connect('as400_fds')

      sql = "SELECT a.cmcsnm, '01-' || a.cmcsno, b.sashp#, b.sashnm, " +
        "b.sasad1, b.sasad2, b.sascty, b.sashst, b.saszip " +
        "FROM cusms AS a " +
        "JOIN addr AS b ON b.sacsno = a.cmcsno " +
        "WHERE a.cmcsno = '#{account_number}' " +
        "AND b.sasusp != 'S' " +
        "ORDER BY CAST(b.sashp# AS INTEGER)"

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


    @attendees = @event.on_site_attendees.order(:created_at)

    if @attendees.any?
      bold_format = Spreadsheet::Format.new :weight => :bold
      header_row = [
        'Event Name', 'Created Date', 'Created Time', 'Badge Type',
        'Created from CRM Contact?', 'First Name', 'Last Name',
        'Account Name', 'Account #', 'Street 1', 'Street 2',
        'City', 'State', 'Zip Code', 'Email', 'Phone', 'Sales Rep'
      ]

      export = Spreadsheet::Workbook.new
      sheet = export.create_worksheet name: "On-Site Attendees"

      sheet.insert_row(0, header_row)
      sheet.row(0).default_format = bold_format

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

      @attendees.each do |attendee|
        created_date = attendee[:created_at].strftime("%m/%d/%Y")
        created_time = attendee[:created_at].strftime("%l:%M%p")
        created_from_crm = attendee[:contact_in_crm] ? "TRUE" : "FALSE"

        attendee_row = [
          @event.name, created_date, created_time, attendee[:badge_type],
          created_from_crm, attendee[:first_name], attendee[:last_name],
          attendee[:account_name], attendee[:account_number],
          attendee[:street1], attendee[:street2], attendee[:city],
          attendee[:state], attendee[:zip_code], attendee[:email],
          attendee[:phone], attendee[:salesrep]
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

  def crm_contacts_base_sql_query
    statement = "SELECT a.FirstName, a.LastName, b.Name, " +
      "b.icbcore_ExtAccountID, d.Line1, d.Line2, d.City, d.StateOrProvince, " +
      "d.PostalCode, a.EMailAddress1, a.Telephone1, c.FullName, a.ContactId " +
      "FROM ContactBase AS a " +
      "JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId " +
      "JOIN SystemUserBase AS c ON a.OwnerId = c.SystemUserId " +
      "JOIN CustomerAddressBase AS d ON a.ContactId = d.ParentId " +
      "WHERE a.StateCode = '0' " +
      "AND d.AddressNumber = '1' "
    statement
  end

  def create_crm_campaign_response_existing_customer(contact_id)
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

  def create_crm_campaign_response_new_customer
    campaign_id = find_event_today
    return false unless campaign_id
    owner_id = assign_salesrep

    create_with_new_in_crm(owner_id, campaign_id)
  end

  def update_crm_campaign_response_new_customer
    if @update_fields['salesrep']
      campaign_id = query_campaign_id_for_campaign_response
      owner_id = assign_salesrep

      if delete_crm_campaign_response
        activity_id = create_with_new_in_crm(owner_id, campaign_id)['id'] || nil
        @attendee.update(activity_id: activity_id) if activity_id
      end
    else
      client = crm_connection_soap
      client.update('campaignresponse', @attendee.activity_id, changed_fields)
    end
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

  def delete_crm_campaign_response
    client = crm_connection_soap
    client.delete('campaignresponse', @attendee.activity_id)
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

  def find_event_today
    event = @event.crm_campaigns.where(
      "? BETWEEN event_start_date AND event_end_date", Date.today #Date.new(2016,12,15)
    ).first

    event ? event.campaign_id : false
  end

  def assign_salesrep
    owner_id = nil
    
    if @attendee.salesrep
      salesrep = @attendee.salesrep.split(' ', 2)
      if salesrep.count == 2
        conditions = "AND LastName LIKE '%#{salesrep[1]}%'"
      else
        conditions = "OR LastName LIKE '%#{salesrep[0]}%'"
      end

      sql = "SELECT SystemUserId FROM SystemUserBase " +
        "WHERE FirstName LIKE '%#{salesrep[0]}%' " + conditions

      db = crm_connection_sql
      query = db.execute(sql)
      salesrep_matches = query.each(:symbolize_keys => true)
      db.close unless db.closed?
      owner_id = salesrep_matches.first[:SystemUserId] if salesrep_matches.any?
    end
    
    # Assign to Jess Spencer if salesrep not found/not provided
    owner_id = '3A543400-4C6A-E211-A54A-00265585B80D' unless owner_id
    owner_id
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
