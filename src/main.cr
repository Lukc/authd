require "uuid"
require "option_parser"
require "openssl"

require "jwt"
require "passwd"
require "ipc"

require "./authd.cr"

extend AuthD

class IPC::Connection
	def send(type : AuthD::Response::Type, payload : String)
		send type.to_u8, payload
	end
end

authd_passwd_file = "passwd"
authd_group_file = "group"
authd_jwt_key = "nico-nico-nii"

OptionParser.parse do |parser|
	parser.on "-u file", "--passwd-file file", "passwd file." do |name|
		authd_passwd_file = name
	end

	parser.on "-g file", "--group-file file", "group file." do |name|
		authd_group_file = name
	end

	parser.on "-K file", "--key-file file", "JWT key file" do |file_name|
		authd_jwt_key = File.read(file_name).chomp
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser

		exit 0
	end
end

passwd = Passwd.new authd_passwd_file, authd_group_file

##
# Provides a JWT-based authentication scheme for service-specific users.
IPC::Service.new "auth" do |event|
	if event.is_a? IPC::Exception
		puts "oh no"
		pp! event
		next
	end

	case event
	when IPC::Event::Message
		request = Request.from_ipc event.message

		response = case request
		when Request::GetToken
			user = passwd.get_user request.login, request.password

			if user.nil?
				next Response::Error.new "invalid credentials"
			end

			token = JWT.encode user.to_h, authd_jwt_key, JWT::Algorithm::HS256

			Response::Token.new token
		when Request::AddUser
			if request.shared_key != authd_jwt_key
				next Response::Error.new "invalid authentication key"
			end

			if passwd.user_exists? request.login
				next Response::Error.new "login already used"
			end

			user = passwd.add_user request.login, request.password

			Response::UserAdded.new user
		when Request::GetUserByCredentials
			user = passwd.get_user request.login, request.password

			if user
				Response::User.new user
			else
				Response::Error.new "user not found"
			end
		when Request::GetUser
			user = passwd.get_user request.uid

			if user
				Response::User.new user
			else
				Response::Error.new "user not found"
			end
		when Request::ModUser
			if request.shared_key != authd_jwt_key
				next Response::Error.new "invalid authentication key"
			end

			password_hash = request.password.try do |s|
				Passwd.hash_password s
			end

			passwd.mod_user request.uid, password_hash: password_hash

			Response::UserEdited.new request.uid
		else
			Response::Error.new "unhandled request type"
		end

		event.connection.send response
	end
end

