Adauth.configure do |c|
  # DiVal AD Config
  # c.domain = "mainoffice.dival.com"
  # c.query_user = "printers"
  # c.query_password = "!printers!"
  # c.server = "10.220.0.230"
  # c.base = "dc=mainoffice, dc=dival, dc=com"
  # c.allowed_groups = ["DiVal Safety Events", Domain Admins"]

  # Provident AD Config
  c.domain = "provident.local"
  c.query_user = "mweick"
  c.query_password = "HHockey1818"
  c.server = "10.2.10.2"
  c.base = "ou=Administrators, dc=provident, dc=local"

  # The LDAP base of your domain/intended users
  # For all users in your domain the base would be: dc=example, dc=com
  # OUs can be prepeneded to restrict access to your app
  # c.base = "dc=mainoffice, dc=dival, dc=com"

  # If your DC is using SSL, the port may be 636.
  # c.port = 389

  # If your DC is using SSL, set encryption to :simple_tls
  # c.encryption = :simple_tls

  # Windows Security groups to allow
  # Only allow members of set windows security groups to login
  # Takes an array for group names
  # c.allowed_groups = ["Domain Admins"]

  # Windows Security groups to deny
  # Only allow users who aren't in these groups to login
  # Takes an array for group names
  # c.denied_groups = ["Group1", "Group2"]
end