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
    current_user != 'check-in@divalsafety.com'
  end

  def require_user
    log_in_message unless logged_in?
  end

  def require_user_event_redirect
    unless logged_in?
      session[:return_to] = request.url
      log_in_message
    end
  end

  def require_admin
    access_denied_message unless admin?
  end

  def log_in_message
    flash.alert = "Please log in."
    redirect_to login_path
  end

  def access_denied_message
    flash.alert = "Admin access is required to do that."
    redirect_to root_path
  end

  def sanitize(filename)
    filename.gsub(/[\\\/:*"'?<>|]/, '')
  end
end
