require "json"

require "./token.cr"

class AuthD::User
	include JSON::Serializable

	enum PermissionLevel
		None
		Read
		Edit
		Admin

		def to_json(o)
			to_s.downcase.to_json o
		end
	end

	class Contact
		include JSON::Serializable

		property email     : String?
		property phone     : String?

		def initialize(@email = nil, @phone = nil)
		end
	end

	# Public.
	property login         : String
	property uid           : Int32
	property profile       : JSON::Any?

	# Private.
	property contact       : Contact
	property password_hash : String
	# service => resource => permission level
	property permissions   : Hash(String, Hash(String, PermissionLevel))
	property configuration : Hash(String, Hash(String, JSON::Any))

	def to_token
		Token.new @login, @uid
	end

	def initialize(@uid, @login, @password_hash)
		@contact       = Contact.new
		@permissions   = Hash(String, Hash(String, PermissionLevel)).new
		@configuration = Hash(String, Hash(String, JSON::Any)).new
	end

	class Public
		include JSON::Serializable

		property login   : String
		property uid     : Int32
		property profile : JSON::Any?

		def initialize(@uid, @login, @profile)
		end
	end

	def to_public : Public
		Public.new @uid, @login, @profile
	end
end

