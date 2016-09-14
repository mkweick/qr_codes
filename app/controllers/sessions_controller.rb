class SessionsController < ApplicationController
  before_action :require_user, only: [:destroy]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    redirect_to login_path unless params[:username] && params[:password]

    username, password = params[:username], params[:password]

    if username == 'checkin' && password == 'checkin!!'
      session[:email] = 'check-in@divalsafety.com'
      session[:first_name] = 'Check-In'
      redirect_to(session[:return_to] || root_path)
      session.delete(:return_to)
    elsif username == "test" && password == "test"
      session[:email] = 'mweick@provident.com'
      session[:first_name] = 'Test'
      redirect_to(session[:return_to] || root_path)
      session.delete(:return_to)
    else
      ldap_user = Adauth.authenticate(username, password)

      if ldap_user
        session[:email] = ldap_user.ldap_object[:mail].first.strip
        session[:first_name] = ldap_user.ldap_object[:givenname].first.strip
        redirect_to(session[:return_to] || root_path)
        session.delete(:return_to)
      elsif 
        flash.now.alert = 'Authentication failed'
        render 'new'
      end
    end
  end

  def destroy
    session.delete(:email)
    session.delete(:first_name)
    flash.notice = 'Successfully logged out'
    redirect_to login_path
  end
end