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
      flash.notice = "Event type #{@type.name} created."
      redirect_to types_path
    else
      render :new
    end
  end

  def edit
    unless @type
      flash.alert = "That event type doesn't exist."
      redirect_to types_path
    end
  end

  def update
    if @type.update(type_params)
      flash.notice = "Event type updated."
      redirect_to types_path
    else
      @type.reload
      render :edit
    end
  end

  def destroy
    if @type
      if @type.destroy
        flash.notice = "Event type #{@type.name} deleted."
      else
        flash.alert = "Event type #{@type.name} can't be deleted. Contact IT."
      end
    else
      flash.alert = "That event type doesn't exist."
    end
    redirect_to types_path
  end

  private

  def set_type
    @type = Type.find(params[:id]) if params[:id]
  end

  def type_params
    params.require(:type).permit(:name)
  end
end