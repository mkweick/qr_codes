class TypesController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_type, except: [:index, :new, :create]

  def index
    @types = Type.sorted_types
  end

  def new
    @type = Type.new
  end

  def create
    @type = Type.new(type_params)

    if @type.save
      flash.notice = "Event type created."
      redirect_to types_path
    else
      render 'new'
    end
  end

  def edit; end

  def update
    if @type.update(type_params)
      flash.notice = "Event type updated."
      redirect_to types_path
    else
      @type.reload
      render 'edit'
    end
  end

  def destroy
    if @type.destroy
      flash.notice = "Event type deleted."
    else
      flash.alert = "Event type can't be deleted. Contact IT."
    end

    redirect_to types_path
  end

  private

  def set_type
    @type = Type.find(params[:id]) if params[:id]
  end

  def type_params
    params.require(:type).permit(:name, :multiple_locations)
  end
end