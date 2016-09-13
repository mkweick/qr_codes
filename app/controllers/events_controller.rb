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
      @batch = @event.batches.new
      @batches = @event.batches.order(:number)
      @locations = Location.sorted_locations.pluck(:city) if @event.multiple_locations
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def edit
    if @event
      event_name = @event.name.split(' ')

      @year = event_name.pop
      @years = Time.now.year..(Time.now.year + 2)

      @type = event_name.join(' ')
      @types = Type.sorted_types.pluck(:name)
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
      event_name = @event.name.split(' ')
      
      @year = event_name.pop
      @years = Time.now.year..(Time.now.year + 2)

      @type = event_name.join(' ')
      @types = Type.sorted_types.pluck(:name)
      
      render 'edit'
    end
  end

  def destroy
    if @event
      if @event.update(status: '3')
        flash.notice = 'Event deleted. Permanently deleted after 3 days.'
        redirect_to root_path
      else
        @batch = @event.batches.new
        @batches = @event.batches.order(:number)
        @locations = Location.sorted_locations.pluck(:city) if @event.multiple_locations
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
        @batch = @event.batches.new
        @batches = @event.batches.order(:number)
        @locations = Location.sorted_locations.pluck(:city) if @event.multiple_locations
        render 'show'
      end
    else
      flash.alert = "Event not found."
      redirect_to root_path
    end
  end

  def archives
    @archives = Event.sorted_archives
    @deleted = Event.sorted_deleted
  end

  def activate
    if @event
      if @event.status == '2' || @event.status == '3'
        if @event.update(status: '1')
          flash.notice = "Event activated."
          redirect_to root_path
        else
          @archives = Event.sorted_archives
          @deleted = Event.sorted_deleted
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
    FileUtils.mkdir(Rails.root.join('events', event.to_s))
  end
end