class EventsController < ApplicationController
  before_action :require_user, except: [:index]
  before_action :require_user_no_redirect, only: [:create, :download]
  before_action :require_admin, except: [:index, :upload, :upload_batch,
    :download, :on_site_badge, :crm_contact, :on_demand, :generate_crm]
  before_action :set_event_name, except: [:index, :update, :upload, :archives]
  skip_before_action :verify_authenticity_token, only: [:create]

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
    @event = Event.create(name: event_name, multiple_locations: multi_type)

    if @event.save
      flash.notice = "Event created successfully."
      redirect_to root_path
    else
      @events = Event.sorted_active_events
      @types = Type.sorted_types.pluck(:name)
      @years = Time.now.year..(Time.now.year + 2)
      render :index
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

  private

  def set_event_name
    @event = Event.find(params[:id]) if params[:id]
  end
end