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
      make_event_dir
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
    if attendee_upload_template?
      send_attendee_template
    else
      flash.alert = "Attendee Template file could not be found."
      redirect_to event_path(@event)
    end
  end

  def download_employee_template
    if employee_upload_template?
      send_employee_template
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

  def make_event_dir
    delete_event_dir
    delete_attendees_export_dir
    FileUtils.mkdir(event_dir_path)
    FileUtils.mkdir(attendees_export_dir)
  end

  def event_dir_path
    Rails.root.join('events', @event.id.to_s)
  end

  def delete_event_dir
    FileUtils.remove_dir(event_dir_path) if Dir.exist?(event_dir_path)
  end

  def attendees_export_dir
    Rails.root.join(event_dir_path, 'attendees_export')
  end

  def delete_attendees_export_dir
    FileUtils.remove_dir(attendees_export_dir) if Dir.exist?(attendees_export_dir)
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

        unless qr_codes?(batch) && export_file?(batch)
          batch.update(processing_status: '1')
        end
      end
    end
  end

  def qr_codes?(batch)
    qr_codes_path = Rails.root.join('events', batch.event_id.to_s,
      batch.number.to_s, 'qr_codes.zip')

    File.exist?(qr_codes_path)
  end

  def export_file?(batch)
    export_file_path = Rails.root.join('events', batch.event_id.to_s,
      batch.number.to_s, 'export', 'export.xls')

    File.exist?(export_file_path)
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

  def attendee_upload_template
    Rails.root.join('events', 'upload_templates', 'ATTENDEE_UPLOAD_TEMPLATE.xls')
  end

  def attendee_upload_template?
    File.exist?(attendee_upload_template)
  end

  def send_attendee_template
    send_file(attendee_upload_template, type: 'application/vnd.ms-excel')
  end

  def employee_upload_template
    Rails.root.join('events', 'upload_templates', 'EMPLOYEE_UPLOAD_TEMPLATE.xls')
  end

  def employee_upload_template?
    File.exist?(employee_upload_template)
  end

  def send_employee_template
    send_file(employee_upload_template, type: 'application/vnd.ms-excel')
  end
end