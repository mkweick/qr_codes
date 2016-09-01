class SessionsController < ApplicationController
  before_action :require_user, only: [:destroy]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    redirect_to login_path unless params[:username] && params[:password]

    ldap_user = Adauth.authenticate(params[:username], params[:password])

    if ldap_user
      session[:email] = ldap_user.ldap_object[:userprincipalname].first
      session[:first_name] = ldap_user.ldap_object[:givenname].first
      redirect_to root_path
    else
      flash.now.alert = 'Authentication failed'
      render 'new'
    end
  end

  def destroy
    session.delete(:email)
    session.delete(:first_name)
    flash.notice = 'Successfully logged out'
    redirect_to login_path
  end
end