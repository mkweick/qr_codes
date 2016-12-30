class EventsController < ApplicationController
  before_action :require_user, except: [:index, :show]
  before_action :require_user_event_redirect, only: [:show]
  before_action :require_admin, except: [:index]
  before_action :set_event, except: [:index, :create, :archives]
  before_action :require_active_event, except: [:index, :create, :archives, :activate]

  def index
    redirect_to login_path unless logged_in?

    @events = Event.sorted_active_events
    @event = Event.new
    @types = Type.sorted_types.pluck(:name)
    @years = Time.now.year..(Time.now.year + 2)
  end

  def create
    @event = Event.new(event_params)
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
    batches_status_check
  end

  def edit
    set_event_form_info
  end

  def update
    if @event.update(event_params)
      flash.notice = "Event updated."
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

  def download_attendee_template
    upload_template = Rails.root.join('events', 'upload_templates',
      'ATTENDEE_UPLOAD_TEMPLATE.xls')

    if File.exist?(upload_template)
      send_file(upload_template, type: 'application/vnd.ms-excel',
        filename: 'ATTENDEE_UPLOAD_TEMPLATE.xls')
    else
      flash.alert = "Attendee Template file could not be found."
      redirect_to event_path(@event)
    end
  end

  def download_employee_template
    upload_template = Rails.root.join('events', 'upload_templates',
      'EMPLOYEE_UPLOAD_TEMPLATE.xls')

    if File.exist?(upload_template)
      send_file(upload_template, type: 'application/vnd.ms-excel',
        filename: 'EMPLOYEE_UPLOAD_TEMPLATE.xls')
    else
      flash.alert = "Employee Template file could not be found."
      redirect_to event_path(@event)
    end
  end

  private

  def event_params
    event_name = params[:type] + ' ' + params[:year]
    multi_type = Type.find_by(name: params[:type]).multiple_locations
    subject = params[:subject] if params[:subject]

    { name: event_name, multiple_locations: multi_type,
      qr_code_email_subject: subject }
  end

  def set_event
    @event = Event.find(params[:id]) if params[:id]
  end

  def make_event_dir(event)
    event_path = Rails.root.join('events', event.to_s)
    attendees_export_path = Rails.root.join(event_path, 'attendees_export')
    FileUtils.remove_dir(event_path) if Dir.exist?(event_path)
    FileUtils.mkdir(event_path)
    FileUtils.mkdir(attendees_export_path)
  end

  def set_event_info
    @attendees_present = @event.on_site_attendees.any?
    @batch = @event.batches.new
    @batches = @event.batches.order(:created_at)
    @locations = Location.sorted_locations.pluck(:name) if @event.multiple_locations
  end

  def batches_status_check
    if @batches.any?
      @batches.each do |batch|
        next unless batch.processing_status == '3'

        qr_codes_path = Rails.root.join('events', batch.event_id.to_s,
          batch.number.to_s, 'qr_codes.zip')
    
        export_path = Rails.root.join('events', batch.event_id.to_s,
          batch.number.to_s, 'export', 'export.xls')

        qr_codes = File.exist?(qr_codes_path)
        export = File.exist?(export_path)

        batch.update(processing_status: '1') unless qr_codes && export
      end
    end
  end

  def set_event_form_info
    event_name = @event.name.split(' ')
    @year = event_name.pop
    @years = Time.now.year..(Time.now.year + 2)
    @type = event_name.join(' ')
    @types = Type.sorted_types.pluck(:name)

    @campaign = @event.crm_campaigns.new
    @campaigns = @event.crm_campaigns.order(:name)
  end

  def set_archives_info
    @archives = Event.sorted_archives
    @deleted = Event.sorted_deleted
  end
end