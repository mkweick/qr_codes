class LocationsController < ApplicationController
  before_action :require_user
  before_action :set_location, except: [:index, :new, :create]

  def index
    @locations = Location.order('lower(city)')
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      flash.notice = "Location #{@location.city} created."
      redirect_to locations_path
    else
      render :new
    end
  end

  def edit
    unless @location
      flash.alert = "That location doesn't exist."
      redirect_to locations_path
    end
  end

  def update
    if @location.update(location_params)
      flash.notice = "Location updated."
      redirect_to locations_path
    else
      @location.reload
      render :edit
    end
  end

  def destroy
    if @location
      if @location.destroy
        flash.notice = "Location #{@location.city} deleted."
      else
        flash.alert = "Location #{@location.city} can't be deleted. Contact IT."
      end
    else
      flash.alert = "That location doesn't exist."
    end
    redirect_to locations_path
  end

  private

  def set_location
    @location = Location.find(params[:id]) if params[:id]
  end

  def location_params
    params.require(:location).permit(:city)
  end
end