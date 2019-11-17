
require "jwt"

require "ipc"

require "./user.cr"

module AuthD
	enum RequestTypes
		GetToken
		AddUser
		GetUser
		GetUserByCredentials
		ModUser # Edit user attributes.
	end

	enum ResponseTypes
		Ok
		MalformedRequest
		InvalidCredentials
		InvalidUser
		UserNotFound # For UID-based GetUser requests.
		AuthenticationError
	end

	class GetTokenRequest
		JSON.mapping({
			# FIXME: Rename to "login" for consistency.
			login: String,
			password: String
		})
	end

	class AddUserRequest
		JSON.mapping({
			# Only clients that have the right shared key will be allowed
			# to create users.
			shared_key: String,

			login: String,
			password: String,
			uid: Int32?,
			gid: Int32?,
			home: String?,
			shell: String?
		})
	end

	class GetUserRequest
		JSON.mapping({
			uid: Int32
		})
	end

	class GetUserByCredentialsRequest
		JSON.mapping({
			login: String,
			password: String
		})
	end

	class ModUserRequest
		JSON.mapping({
			shared_key: String,

			uid: Int32,
			password: String?,
			avatar: String?
		})
	end

	class Client < IPC::Connection
		property key : String

		def initialize
			@key = ""

			initialize "auth"
		end

		def get_token?(login : String, password : String) : String?
			send RequestTypes::GetToken, {
				:login => login,
				:password => password
			}.to_json

			response = read

			if response.type == ResponseTypes::Ok.value.to_u8
				String.new response.payload
			else
				nil
			end
		end

		def get_user?(login : String, password : String) : Passwd::User?
			send RequestTypes::GetUserByCredentials, {
				:login => login,
				:password => password
			}.to_json

			response = read

			if response.type == ResponseTypes::Ok.value.to_u8
				Passwd::User.from_json String.new response.payload
			else
				nil
			end
		end

		def get_user?(uid : Int32)
			send RequestTypes::GetUser, {:uid => uid}.to_json

			response = read

			if response.type == ResponseTypes::Ok.value.to_u8
				User.from_json String.new response.payload
			else
				nil
			end
		end

		def send(type : RequestTypes, payload)
			send type.value.to_u8, payload
		end

		def decode_token(token)
			user, meta = JWT.decode token, @key, JWT::Algorithm::HS256

			user = Passwd::User.from_json user.to_json

			{user, meta}
		end

		# FIXME: Extra options may be useful to implement here.
		def add_user(login : String, password : String) : Passwd::User | Exception
			send RequestTypes::AddUser, {
				:shared_key => @key,
				:login => login,
				:password => password
			}.to_json

			response = read

			payload = String.new response.payload
			case ResponseTypes.new response.type.to_i
			when ResponseTypes::Ok
				Passwd::User.from_json payload
			else
				Exception.new payload
			end
		end

		def mod_user(uid : Int32, password : String? = nil, avatar : String? = nil) : Bool | Exception
			payload = Hash(String, String|Int32).new
			payload["uid"] = uid
			payload["shared_key"] = @key

			password.try do |password|
				payload["password"] = password
			end

			avatar.try do |avatar|
				payload["avatar"] = avatar
			end

			send RequestTypes::ModUser, payload.to_json

			response = read

			case ResponseTypes.new response.type.to_i
			when ResponseTypes::Ok
				true
			else
				Exception.new String.new response.payload
			end
		end
	end
end

