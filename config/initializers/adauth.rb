Adauth.configure do |c|
  # DiVal AD Config
  c.domain = ENV['AD_DOMAIN']
  c.query_user = ENV['AD_UN']
  c.query_password = ENV['AD_PW']
  c.server = ENV['AD_SERVER']
  c.base = ENV['AD_BASE']
  c.allowed_ous = ['Staff']
  #c.allowed_groups = ["Events QR Codes Web App Access", "Domain Admins"]

  # The LDAP base of your domain/intended users
  # For all users in your domain the base would be: dc=example, dc=com
  # OUs can be prepeneded to restrict access to your app
  # c.base = "dc=example, dc=com"

  # If your DC is using SSL, the port may be 636.
  # c.port = 389

  # If your DC is using SSL, set encryption to :simple_tls
  # c.encryption = :simple_tls

  # Windows Security groups to allow
  # Only allow members of set windows security groups to login
  # Takes an array for group names
  # c.allowed_groups = ["Test Group"]

  # Windows Security groups to deny
  # Only allow users who aren't in these groups to login
  # Takes an array for group names
  # c.denied_groups = ["Group1", "Group2"]
end