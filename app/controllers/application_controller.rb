class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :logged_in?

  def current_user
    @current_user ||= session[:email] if session[:email]
  end

  def logged_in?
    !!current_user
  end

  def require_user
    unless logged_in?
      session[:return_to] = request.url
      log_in_message
    end
  end

  def log_in_message
    flash.alert = "Please log in."
    redirect_to login_path
  end
end
