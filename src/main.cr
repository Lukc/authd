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
		client = event.connection

		message = event.message
		payload = message.payload

		request = Request.from_ipc message

		case request
		when Request::GetToken
			user = passwd.get_user request.login, request.password

			if user.nil?
				client.send Response::Type::InvalidCredentials.value.to_u8, ""
				
				next
			end

			client.send Response::Type::Ok.value.to_u8,
				JWT.encode user.to_h, authd_jwt_key, JWT::Algorithm::HS256
		when Request::AddUser
			if request.shared_key != authd_jwt_key
				client.send Response::Type::AuthenticationError, "Invalid authentication key."
				next
			end

			if passwd.user_exists? request.login
				client.send Response::Type::InvalidUser, "Another user with the same login already exists."

				next
			end

			user = passwd.add_user request.login, request.password

			client.send Response::Type::Ok, user.sanitize!.to_json
		when Request::GetUserByCredentials
			user = passwd.get_user request.login, request.password

			if user
				client.send Response::Type::Ok, user.sanitize!.to_json
			else
				client.send Response::Type::UserNotFound, ""
			end
		when Request::GetUser
			user = passwd.get_user request.uid

			if user
				client.send Response::Type::Ok, user.sanitize!.to_json
			else
				client.send Response::Type::UserNotFound, ""
			end
		when Request::ModUser
			if request.shared_key != authd_jwt_key
				client.send Response::Type::AuthenticationError, "Invalid authentication key."
				next
			end

			password_hash = request.password.try do |s|
				Passwd.hash_password s
			end

			passwd.mod_user request.uid, password_hash: password_hash

			client.send Response::Type::Ok, ""
		end
	end
end

