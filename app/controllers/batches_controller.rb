class BatchesController < ApplicationController
  before_action :require_user, except: [:create]
  before_action :require_user_no_redirect, only: [:create]
  before_action :set_event, except: []
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    file = params[:file] if params[:file]

    if file && file.original_filename[-4..-1].downcase == '.xls'
      filename = sanitize(file.original_filename)
      batches = @event.batches.pluck(:number)
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
    else
      flash.alert = "Upload file must be <strong>.xls</strong> format."
      redirect_to event_path(@event)
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