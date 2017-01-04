class SessionsController < ApplicationController

  def new
    redirect_to root_path if logged_in?
  end

  def create
    redirect_to login_path unless params[:username] && params[:password]

    username, password = params[:username], params[:password]
    user = Adauth.authenticate(username, password)

    if user
      if enabled_crm_user?(username)
        set_session_params(user, username, password)
        redirect_to(session[:return_to] || root_path)
        session.delete(:return_to)
      else
        flash.now.alert = "Must be a valid CRM User"
        render 'new'
      end
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

  def enabled_crm_user?(username)
    db = crm_connection_sql
    username = db.escape("DIVAL\\#{username}")
    sql = "SELECT IsDisabled FROM SystemUserBase " +
      "WHERE DomainName = '#{username}' AND IsDisabled = '0'"
    query = db.execute(sql)
    result = query.each(:symbolize_keys => true).first
    db.close unless db.closed?
    result
  end

  def set_session_params(user, username, password)
    user_params = user.ldap_object
    email = user_params[:mail].first
    member_of = user.cn_groups_nested
    access_level = member_of.include?('Events QR Admin Access') ? '1' : '0'

    session[:name] = user_params[:givenname].first || 'User'
    session[:email] = email
    session[:user] = [encrypt(username), encrypt(password)]
    session[:access] = access_level
  end

  def encrypt(string)
    encrypted_string = ''

    string.strip.each_char.with_index do |char, idx|
      seperators = ['@', '#', '$', '%', '&']
      encrypted_char = seperators.sample + (char.ord * 5).to_s
      encrypted_char = encrypted_char.slice(1..-1) if idx == 0
      encrypted_string += encrypted_char
    end

    encrypted_string
  end
end