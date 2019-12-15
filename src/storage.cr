require "json"

class AuthD::User
	include JSON::Serializable

	property login         : String
	property password_hash : String?
	property uid           : Int32

	property mail_address  : String

	# FIXME: How would this profile be extended, replaced, checked?
	property profile       : Profile

	class Profile
		include JSON::Serializable

		property full_name   : String?
		property description : String?
		property avatar      : String?
		property website     : String?
	end

	property registration_date : Time

	property groups        : Array(String)

	# application name => configuration object
	property configuration : Hash(String, JSON::Any)
end

class AuthD::Group
	include JSON::Serializable

	property name          : String
	property gid           : Int32
	property members       : Array(String)
end

class AuthD::Storage
	# FIXME: Create new groups and users, generate their ids.
	def initialize(@storage_root)
		@users = DODB::Hash(Int32, User).new "#{@storage_root}/users"
		@users_by_login = @users.new_index "login", &.login
		@users_by_group = @users.new_tags "groups", &.groups

		@groups = DODB::Hash(Int32, Group).new "#{@storage_root}/groups"
		@groups_by_name   = new_index "name", &.name
		@groups_by_member = new_tags "members", &.members
	end
end

