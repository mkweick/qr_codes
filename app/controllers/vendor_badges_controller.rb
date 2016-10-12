class VendorBadgesController < ApplicationController
  before_action :require_user

  def new; end

  def print
    @first_name = params[:first_name].strip if params[:first_name].present?
    @last_name = params[:last_name].strip if params[:last_name].present?
    @vendor_name = params[:vendor_name].strip if params[:vendor_name].present?

    if @first_name && @last_name && @vendor_name
      render layout: false
    else
      flash.now.alert = "Missing required information."
      render 'new'
    end
  end
end