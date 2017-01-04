class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  helper_method :logged_in?, :admin?

  def current_user
    @current_user ||= session[:email] if session[:email]
  end

  def logged_in?
    !!current_user
  end

  def admin?
    session[:access] == '1'
  end

  def require_user
    respond_to do |format|
      format.html { log_in_message_html unless logged_in? }
      format.js { log_in_message_js unless logged_in? }
    end
  end

  def require_user_event_redirect
    unless logged_in?
      session[:return_to] = request.url
      log_in_message_html
    end
  end

  def require_admin
    access_denied_message unless admin?
  end

  def log_in_message_html
    flash.alert = "Please log in."
    redirect_to login_path
  end

  def log_in_message_js
    flash.alert = "Please log in."
    render :js => "window.location = '#{login_path}'"
  end

  def access_denied_message
    flash.alert = "Admin access is required to do that."
    redirect_to root_path
  end

  def require_active_event
    unless @event.status == '1'
      flash.alert = "That event is not active."
      redirect_to root_path
    end
  end

  def sanitize(filename)
    filename.gsub(/[\\\/:*"'?<>|]/, '')
  end

  def crm_connection_sql
    TinyTds::Client.new(
      host: ENV["CRM_DB_HOST"], database: ENV["CRM_DB_NAME"],
      username: ENV["CRM_DB_UN"], password: ENV["CRM_DB_PW"]
    )
  end
end
