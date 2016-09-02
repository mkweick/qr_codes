class EventTypesController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_event_type, except: [:index, :new, :create]

  def index
    @event_types = EventType.order('lower(name)')
  end

  def new
    @event_type = EventType.new
  end

  def create
    @event_type = EventType.new(event_type_params)

    if @event_type.save
      flash.notice = "Event type #{@event_type.name} created."
      redirect_to event_types_path
    else
      render :new
    end
  end

  def edit
    unless @event_type
      flash.alert = "That event type doesn't exist."
      redirect_to event_types_path
    end
  end

  def update
    if @event_type.update(event_type_params)
      flash.notice = "Event type updated."
      redirect_to event_types_path
    else
      @event_type.reload
      render :edit
    end
  end

  def destroy
    if @event_type
      if @event_type.destroy
        flash.notice = "Event type #{@event_type.name} deleted."
      else
        flash.alert = "Event type #{@event_type.name} can't be deleted. Contact IT."
      end
    else
      flash.alert = "That event type doesn't exist."
    end
    redirect_to event_types_path
  end

  private

  def set_event_type
    @event_type = EventType.find(params[:id]) if params[:id]
  end

  def event_type_params
    params.require(:event_type).permit(:name)
  end
end