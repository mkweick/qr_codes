class EventsController < ApplicationController
  before_action :require_user, except: [:index, :show]
  before_action :require_user_event_redirect, only: [:show]
  before_action :require_admin, except: [:index]
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
    subject = params[:subject] if params[:subject]

    @event = Event.new(name: event_name, multiple_locations: multi_type,
      qr_code_email_subject: subject)

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
    subject = params[:subject] if params[:subject]

    if @event.update(name: event_name, multiple_locations: multi_type,
      qr_code_email_subject: subject)
      
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
end