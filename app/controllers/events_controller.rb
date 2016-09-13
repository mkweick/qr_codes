class EventsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :set_event, except: [:index, :create, :archives]
  before_action :require_user, except: [:index, :create]
  before_action :require_user_no_redirect, only: [:create]
  before_action :require_admin, except: [:index]

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
    if @event
      set_event_info
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def edit
    if @event
      set_event_form_info
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
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
    if @event
      if @event.update(status: '3')
        flash.notice = 'Event deleted. Permanently deleted after 3 days.'
        redirect_to root_path
      else
        set_event_info
        render 'show'
      end
    else
      flash.alert = 'Event not found.'
      redirect_to root_path
    end
  end

  def archive
    if @event
      if @event.update(status: '2')
        flash.notice = "Event archived."
        redirect_to root_path
      else
        set_event_info
        render 'show'
      end
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def archives
    set_archives_info
  end

  def activate
    if @event
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
    else
      flash.alert = 'Event not found.'
      redirect_to root_path
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