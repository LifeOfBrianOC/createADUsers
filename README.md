# createADUsers
A script to create OUs/Groups/Users from CSV input
it will do the following
Check for AD Powershell Module & install if not present
Import csv (and validate csv path)
Check for existing OU - Create if not present
Check for existing Group - Create if not present
Add Group to Group
Check for existing Users - Create if not present
Check if users are members of groups
Add Users to groups
