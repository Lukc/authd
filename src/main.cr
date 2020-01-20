require "uuid"
require "option_parser"
require "openssl"

require "jwt"
require "ipc"
require "dodb"

require "./authd.cr"

extend AuthD

class AuthD::Service
	property registrations_allowed = false

	@users_per_login : DODB::Index(User)
	@users_per_uid   : DODB::Index(User)

	def initialize(@storage_root : String, @jwt_key : String)
		@users = DODB::DataBase(User).new @storage_root
		@users_per_uid   = @users.new_index "uid",   &.uid.to_s
		@users_per_login = @users.new_index "login", &.login

		@last_uid_file = "#{@storage_root}/last_used_uid"
	end

	def hash_password(password : String) : String
		digest = OpenSSL::Digest.new "sha256"
		digest << password
		digest.hexdigest
	end

	def new_uid
		begin
			uid = File.read(@last_uid_file).to_i
		rescue
			uid = 999
		end

		uid += 1

		File.write @last_uid_file, uid.to_s

		uid
	end

	def handle_request(request : AuthD::Request?, connection : IPC::Connection)
		case request
		when Request::GetToken
			user = @users_per_login.get request.login

			if user.password_hash != hash_password request.password
				return Response::Error.new "invalid credentials"
			end

			if user.nil?
				return Response::Error.new "invalid credentials"
			end

			token = user.to_token

			Response::Token.new token.to_s @jwt_key
		when Request::AddUser
			if request.shared_key != @jwt_key
				return Response::Error.new "invalid authentication key"
			end

			if @users_per_login.get? request.login
				return Response::Error.new "login already used"
			end

			password_hash = hash_password request.password

			uid = new_uid

			user = User.new uid, request.login, password_hash

			request.profile.try do |profile|
				user.profile = profile
			end

			@users << user

			Response::UserAdded.new user.to_public
		when Request::GetUserByCredentials
			user = @users_per_login.get? request.login

			unless user
				return Response::Error.new "invalid credentials"
			end
			
			if hash_password(request.password) != user.password_hash
				return Response::Error.new "invalid credentials"
			end

			Response::User.new user.to_public
		when Request::GetUser
			uid_or_login = request.user
			user = if uid_or_login.is_a? Int32
				@users_per_uid.get? uid_or_login.to_s
			else
				@users_per_login.get? uid_or_login
			end

			if user.nil?
				return Response::Error.new "user not found"
			end

			Response::User.new user.to_public
		when Request::ModUser
			if request.shared_key != @jwt_key
				return Response::Error.new "invalid authentication key"
			end

			user = @users_per_uid.get? request.uid.to_s

			unless user
				return Response::Error.new "user not found"
			end

			password_hash = request.password.try do |s|
				user.password_hash = hash_password s
			end

			@users_per_uid.update user.uid.to_s, user

			Response::UserEdited.new request.uid
		when Request::Register
			if ! @registrations_allowed
				return Response::Error.new "registrations not allowed"
			end

			if @users_per_login.get? request.login
				return Response::Error.new "login already used"
			end

			uid = new_uid
			password = hash_password request.password

			user = User.new uid, request.login, password

			request.profile.try do |profile|
				user.profile = profile
			end

			@users << user

			Response::UserAdded.new user.to_public
		when Request::UpdatePassword
			user = @users_per_login.get? request.login

			unless user
				return Response::Error.new "invalid credentials"
			end

			if hash_password(request.old_password) != user.password_hash
				return Response::Error.new "invalid credentials"
			end

			user.password_hash = hash_password request.new_password

			@users_per_uid.update user.uid.to_s, user

			Response::UserEdited.new user.uid
		when Request::ListUsers
			# FIXME: Lines too long, repeatedly (>80c with 4c tabs).
			request.token.try do |token|
				user = get_user_from_token token

				return Response::Error.new "unauthorized (user not found from token)"

				return Response::Error.new "unauthorized (user not in authd group)" unless user.permissions["authd"]?.try(&.["*"].>=(User::PermissionLevel::Read))
			end

			request.key.try do |key|
				return Response::Error.new "unauthorized (wrong shared key)" unless key == @jwt_key
			end

			return Response::Error.new "unauthorized (no key nor token)" unless request.key || request.token

			Response::UsersList.new @users.to_h.map &.[1].to_public
		when Request::CheckPermission
			unless request.shared_key == @jwt_key
				return Response::Error.new "unauthorized"
			end

			user = @users_per_uid.get? request.user.to_s

			if user.nil?
				return Response::Error.new "no such user"
			end

			service = request.service
			service_permissions = user.permissions[service]?

			if service_permissions.nil?
				return Response::PermissionCheck.new service, request.resource, user.uid, User::PermissionLevel::None
			end

			resource_permissions = service_permissions[request.resource]?

			if resource_permissions.nil?
				return Response::PermissionCheck.new service, request.resource, user.uid, User::PermissionLevel::None
			end

			return Response::PermissionCheck.new service, request.resource, user.uid, resource_permissions
		when Request::SetPermission
			unless request.shared_key == @jwt_key
				return Response::Error.new "unauthorized"
			end

			user = @users_per_uid.get? request.user.to_s

			if user.nil?
				return Response::Error.new "no such user"
			end

			service = request.service
			service_permissions = user.permissions[service]?

			if service_permissions.nil?
				service_permissions = Hash(String, User::PermissionLevel).new
				user.permissions[service] = service_permissions
			end

			if request.permission.none?
				service_permissions.delete request.resource
			else
				service_permissions[request.resource] = request.permission
			end

			@users_per_uid.update user.uid.to_s, user

			Response::PermissionSet.new user.uid, service, request.resource, request.permission
		else
			Response::Error.new "unhandled request type"
		end
	end

	def get_user_from_token(token : String)
		token_payload = Token.from_s(token, @jwt_key)

		@users_per_uid.get? token_payload.uid.to_s
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

authd_storage = "storage"
authd_jwt_key = "nico-nico-nii"
authd_registrations = false

begin
	OptionParser.parse do |parser|
		parser.banner = "usage: authd [options]"

		parser.on "-s directory", "--storage directory", "Directory in which to store users." do |directory|
			authd_storage = directory
		end

		parser.on "-K file", "--key-file file", "JWT key file" do |file_name|
			authd_jwt_key = File.read(file_name).chomp
		end

		parser.on "-R", "--allow-registrations" do
			authd_registrations = true
		end

		parser.on "-h", "--help", "Show this help" do
			puts parser

			exit 0
		end
	end

	AuthD::Service.new(authd_storage, authd_jwt_key).tap do |authd|
		authd.registrations_allowed = authd_registrations
	end.run
rescue e : OptionParser::Exception
	STDERR.puts e.message
rescue e
	STDERR.puts "exception raised: #{e.message}"
	e.backtrace.try &.each do |line|
		STDERR << "  - " << line << '\n'
	end
end

