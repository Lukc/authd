require "uuid"
require "option_parser"
require "openssl"

require "jwt"
require "passwd"
require "ipc"
require "fs"

require "./authd.cr"

extend AuthD

class AuthD::Service
	property registrations_allowed = false

	def initialize(@passwd : Passwd, @jwt_key : String, @extras_root : String)
	end

	def handle_request(request : AuthD::Request?, connection : IPC::Connection)
		case request
		when Request::GetToken
			user = @passwd.get_user request.login, request.password

			if user.nil?
				return Response::Error.new "invalid credentials"
			end

			token = JWT.encode user.to_h, @jwt_key, JWT::Algorithm::HS256

			Response::Token.new token
		when Request::AddUser
			if request.shared_key != @jwt_key
				return Response::Error.new "invalid authentication key"
			end

			if @passwd.user_exists? request.login
				return Response::Error.new "login already used"
			end

			user = @passwd.add_user request.login, request.password

			Response::UserAdded.new user
		when Request::GetUserByCredentials
			user = @passwd.get_user request.login, request.password

			if user
				Response::User.new user
			else
				Response::Error.new "user not found"
			end
		when Request::GetUser
			user = @passwd.get_user request.uid

			if user
				Response::User.new user
			else
				Response::Error.new "user not found"
			end
		when Request::ModUser
			if request.shared_key != @jwt_key
				return Response::Error.new "invalid authentication key"
			end

			password_hash = request.password.try do |s|
				Passwd.hash_password s
			end

			@passwd.mod_user request.uid, password_hash: password_hash

			Response::UserEdited.new request.uid
		when Request::Register
			if ! @registrations_allowed
				return Response::Error.new "registrations not allowed"
			end

			if @passwd.user_exists? request.login
				return Response::Error.new "login already used"
			end

			user = @passwd.add_user request.login, request.password

			Response::UserAdded.new user
		when Request::GetExtra
			user = get_user_from_token request.token

			return Response::Error.new "invalid token" unless user

			storage = FS::Hash(String, JSON::Any).new "#{@extras_root}/#{user.uid}"

			Response::Extra.new user.uid, request.name, storage[request.name]?
		when Request::SetExtra
			user = get_user_from_token request.token

			return Response::Error.new "invalid token" unless user

			storage = FS::Hash(String, JSON::Any).new "#{@extras_root}/#{user.uid}"

			storage[request.name] = request.extra

			Response::ExtraUpdated.new user.uid, request.name, request.extra
		when Request::UpdatePassword
			user = @passwd.get_user request.login, request.old_password

			return Response::Error.new "invalid credentials" unless user

			password_hash = Passwd.hash_password request.new_password

			@passwd.mod_user user.uid, password_hash: password_hash

			Response::UserEdited.new user.uid
		when Request::ListUsers
			request.token.try do |token|
				user = get_user_from_token token

				return Response::Error.new "unauthorized (user not found from token)" unless user

				return Response::Error.new "unauthorized (user not in authd group)" unless user.groups.any? &.==("authd")
			end

			request.key.try do |key|
				return Response::Error.new "unauthorized (wrong shared key)" unless key == @jwt_key
			end

			return Response::Error.new "unauthorized (no key nor token)" unless request.key || request.token

			Response::UsersList.new @passwd.get_all_users
		else
			Response::Error.new "unhandled request type"
		end
	end

	def get_user_from_token(token)
		user, meta = JWT.decode token, @jwt_key, JWT::Algorithm::HS256

		Passwd::User.from_json user.to_json
	end

	def run
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
				begin
					request = Request.from_ipc event.message

					response = handle_request request, event.connection

					event.connection.send response
				rescue e
					STDERR.puts "error: #{e.message}"
				end
			end
		end
	end
end

authd_passwd_file = "passwd"
authd_group_file = "group"
authd_jwt_key = "nico-nico-nii"
authd_registrations = false
authd_extra_storage = "storage"

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

	parser.on "-S dir", "--extra-storage dir", "Storage for extra user-data." do |directory|
		authd_extra_storage = directory
	end

	parser.on "-R", "--allow-registrations" do
		authd_registrations = true
	end

	parser.on "-h", "--help", "Show this help" do
		puts parser

		exit 0
	end
end

passwd = Passwd.new authd_passwd_file, authd_group_file

AuthD::Service.new(passwd, authd_jwt_key, authd_extra_storage).tap do |authd|
	authd.registrations_allowed = authd_registrations
end.run

