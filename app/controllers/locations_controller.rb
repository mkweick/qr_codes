class LocationsController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_location, except: [:index, :new, :create]

  def index
    @locations = Location.sorted_locations
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)

    if @location.save
      flash.notice = "Location created."
      redirect_to locations_path
    else
      render 'new'
    end
  end

  def edit; end

  def update
    if @location.update(location_params)
      flash.notice = "Location updated."
      redirect_to locations_path
    else
      @location.reload
      render 'edit'
    end
  end

  def destroy
    if @location.destroy
      flash.notice = "Location deleted."
    else
      flash.alert = "Location can't be deleted. Contact IT."
    end
    
    redirect_to locations_path
  end

  private

  def set_location
    @location = Location.find(params[:id]) if params[:id]
  end

  def location_params
    params.require(:location).permit(:name)
  end
end