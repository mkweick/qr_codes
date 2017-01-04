class SessionsController < ApplicationController

  def new
    redirect_to root_path if logged_in?
  end

  def create
    redirect_to login_path unless params[:username] && params[:password]

    username, password = params[:username], params[:password]
    user = Adauth.authenticate(username, password)

    if user
      set_session_params(user)
      redirect_to(session[:return_to] || root_path)
      session.delete(:return_to)
    else 
      flash.now.alert = 'Authentication failed'
      render 'new'
    end
  end

  def destroy
    if logged_in?
      session.delete(:name)
      session.delete(:email)
      session.delete(:guid)
      session.delete(:access)
    end

    flash.notice = 'Successfully logged out'
    redirect_to login_path
  end

  private

  def set_session_params(user)
    user_params = user.ldap_object
    email = user_params[:mail].first
    member_of = user.cn_groups_nested
    access_level = member_of.include?('Events QR Admin Access') ? '1' : '0'

    session[:name] = user_params[:givenname].first || 'User'
    session[:email] = email
    session[:guid] = crm_user_id(email)
    session[:access] = access_level
  end

  def crm_user_id(email)
    if email
      db = crm_connection_sql
      email = db.escape(email)
      sql = "SELECT SystemUserId FROM SystemUserBase " +
        "WHERE InternalEmailAddress = '#{email}'"
      
      query = db.execute(sql)
      user = query.each(:symbolize_keys => true)
      db.close unless db.closed?

      user.any? ? user.first[:SystemUserId] : nil
    else
      nil
    end
  end
end