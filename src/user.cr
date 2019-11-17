require "json"

require "passwd"

class Passwd::User
	JSON.mapping({
		login: String,
		password_hash: String,
		uid: Int32,
		gid: Int32,
		home: String,
		shell: String,
		groups: Array(String),
		full_name: String?,
		office_phone_number: String?,
		home_phone_number: String?,
		other_contact: String?,
	})

	def sanitize!
		@password_hash = "x"
		self
	end

	def to_h
		{
			:login => @login,
			:password_hash => "x", # Not real hash in JWT.
			:uid => @uid,
			:gid => @gid,
			:home => @home,
			:shell => @shell,
			:groups => @groups,
			:full_name => @full_name,
			:office_phone_number => @office_phone_number,
			:home_phone_number => @home_phone_number,
			:other_contact => @other_contact
		}
	end
end

