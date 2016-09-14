class EventsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :update,
    :destroy, :archive, :activate]
  before_action :require_user, except: [:index, :show]
  before_action :require_user_event_redirect, only: [:show]
  before_action :require_admin, except: [:index, :on_site_badge, :crm_contact,
    :on_demand, :generate_crm]
  before_action :set_event, except: [:index, :create, :archives]

  def index
    redirect_to login_path unless logged_in?

    @events = Event.sorted_active_events
    @event = Event.new
    @types = Type.sorted_types.pluck(:name)
    @years = Time.now.year..(Time.now.year + 2)
  end

  def create
    event_name = params[:type] + ' ' + params[:year]
    multi_type = Type.find_by(name: params[:type]).multiple_locations
    @event = Event.new(name: event_name, multiple_locations: multi_type)

    if @event.save
      make_event_dir(@event.id)
      flash.notice = "Event created successfully."
      redirect_to root_path
    else
      @events = Event.sorted_active_events
      @types = Type.sorted_types.pluck(:name)
      @years = Time.now.year..(Time.now.year + 2)
      render 'index'
    end
  end

  def show
    set_event_info
  end

  def edit
    set_event_form_info
  end

  def update
    event_name = params[:type] + ' ' + params[:year]
    multi_type = Type.find_by(name: params[:type]).multiple_locations

    if @event.update(name: event_name, multiple_locations: multi_type)
      flash.notice = "Event name updated to #{@event.name}."
      redirect_to event_path(@event)
    else
      @event.reload
      set_event_form_info
      render 'edit'
    end
  end

  def destroy
    if @event.update(status: '3')
      flash.notice = 'Event deleted. Permanently deleted after 3 days.'
      redirect_to root_path
    else
      set_event_info
      render 'show'
    end
  end

  def archive
   if @event.update(status: '2')
      flash.notice = "Event archived."
      redirect_to root_path
    else
      set_event_info
      render 'show'
    end
  end

  def archives
    set_archives_info
  end

  def activate
    if @event.status == '2' || @event.status == '3'
      if @event.update(status: '1')
        flash.notice = "Event activated."
        redirect_to root_path
      else
        set_archives_info
        render 'archives'
      end
    else
      flash.alert = 'Event is already activated.'
      redirect_to root_path
    end
  end

  def download_template
    upload_template = Rails.root.join('events', 'upload_template',
      'QR CODES UPLOAD TEMPLATE.xls')

    if File.exist?(upload_template)
      send_file(upload_template, type: 'application/vnd.ms-excel',
        filename: 'QR CODES UPLOAD TEMPLATE.xls')
    else
      flash.alert = "Template file could not be found."
      redirect_to event_path(@event)
    end
  end

  def on_site_badge
    unless @event_name && event_dir?('active', @event_name)
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def crm_contact
    if @event_name && event_dir?('active', @event_name)
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
        else
          flash.now.alert = "Minimum of 3 characters required for account search."
        end
      end
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def generate_crm
    contact_id = params[:contact_id] if params[:contact_id]

    if @event_name && event_dir?('active', @event_name)
      if contact_id
        make_walk_in_crm_dir(@event_name) unless walk_in_crm_dir?(@event_name)

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

        if contact
          qr_code_path = Rails.root.join('events', 'active', @event_name, 'Walk In CRM')
          qr_code_filename = "#{sanitize(contact[0])}.png"

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

          @qr.save("#{qr_code_path}/#{qr_code_filename}")
        else
          flash.alert = "No contact found."
          redirect_to crm_contact_path(name: @event_name)
        end
      else
        flash.alert = "Contact ID missing."
        redirect_to crm_contact_path(name: @event_name)
      end
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def on_demand

  end

  private

  def set_event
    @event = Event.find(params[:id]) if params[:id]
  end

  def make_event_dir(event)
    event_path = Rails.root.join('events', event.to_s)
    FileUtils.remove_dir(event_path) if Dir.exist?(event_path)
    FileUtils.mkdir(event_path)
  end

  def set_event_info
    @batch = @event.batches.new
    @batches = @event.batches.order(:created_at)
    @locations = Location.sorted_locations.pluck(:name) if @event.multiple_locations
  end

  def set_event_form_info
    event_name = @event.name.split(' ')
    @year = event_name.pop
    @years = Time.now.year..(Time.now.year + 2)
    @type = event_name.join(' ')
    @types = Type.sorted_types.pluck(:name)
  end

  def set_archives_info
    @archives = Event.sorted_archives
    @deleted = Event.sorted_deleted
  end

# --------------------------------------------------------------------------- #

  def set_event_name
    @event_name = params[:name] if params[:name]
  end

  def event_dir?(status, event_name)
    Dir.exist?(Rails.root.join('events', status, event_name))
  end

  def dir_list(path)
    Dir.entries(path).select { |file| file != '.' && file != '..' && file != '.gitignore' }
  end

  def walk_in_crm_dir?(event_name)
    Dir.exist?(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
  end

  def make_walk_in_crm_dir(event_name)
    Dir.mkdir(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
  end
end