class BatchesController < ApplicationController
  before_action :set_event, except: []

  def create
    batches = @event.batches.pluck(:number).sort
    next_batch = batches.any? ? batches.map(&:to_i).sort.last.next.to_s : '1'
    
    @batch = @event.batches.create(batch_params.merge(number: next_batch))

    if @batch.save
      flash.notice = "Batch created."
      redirect_to event_path(@event)
    else
      @batches = @event.batches.order(:number)
      @locations = Location.sorted_locations.pluck(:city) if @event.multiple_locations
      render 'events/show'
    end
  end

  private

  def batch_params
    params.require(:batch).permit(:location, :description)
  end

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end
end