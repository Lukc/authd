
require "jwt"

require "ipc"

require "./user.cr"

module AuthD
	class Response
		enum Type
			Ok
			Malformed
			InvalidCredentials
			InvalidUser
			UserNotFound # For UID-based GetUser requests.
			AuthenticationError
		end
	end

	class Request
		enum Type
			GetToken
			AddUser
			GetUser
			GetUserByCredentials
			ModUser # Edit user attributes.
		end

		class GetToken
			JSON.mapping({
				# FIXME: Rename to "login" for consistency.
				login: String,
				password: String
			})
		end

		class AddUser
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

		class GetUser
			JSON.mapping({
				uid: Int32
			})
		end

		class GetUserByCredentials
			JSON.mapping({
				login: String,
				password: String
			})
		end

		class ModUser
			JSON.mapping({
				shared_key: String,

				uid: Int32,
				password: String?,
				avatar: String?
			})
		end
	end

	class Client < IPC::Connection
		property key : String

		def initialize
			@key = ""

			initialize "auth"
		end

		def get_token?(login : String, password : String) : String?
			send Request::Type::GetToken, {
				:login => login,
				:password => password
			}.to_json

			response = read

			if response.type == Response::Type::Ok.value.to_u8
				String.new response.payload
			else
				nil
			end
		end

		def get_user?(login : String, password : String) : Passwd::User?
			send Request::Type::GetUserByCredentials, {
				:login => login,
				:password => password
			}.to_json

			response = read

			if response.type == Response::Type::Ok.value.to_u8
				Passwd::User.from_json String.new response.payload
			else
				nil
			end
		end

		def get_user?(uid : Int32)
			send Request::Type::GetUser, {:uid => uid}.to_json

			response = read

			if response.type == Response::Type::Ok.value.to_u8
				User.from_json String.new response.payload
			else
				nil
			end
		end

		def send(type : Request::Type, payload)
			send type.value.to_u8, payload
		end

		def decode_token(token)
			user, meta = JWT.decode token, @key, JWT::Algorithm::HS256

			user = Passwd::User.from_json user.to_json

			{user, meta}
		end

		# FIXME: Extra options may be useful to implement here.
		def add_user(login : String, password : String) : Passwd::User | Exception
			send Request::Type::AddUser, {
				:shared_key => @key,
				:login => login,
				:password => password
			}.to_json

			response = read

			payload = String.new response.payload
			case Response::Type.new response.type.to_i
			when Response::Type::Ok
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

			send Request::Type::ModUser, payload.to_json

			response = read

			case Response::Type.new response.type.to_i
			when Response::Type::Ok
				true
			else
				Exception.new String.new response.payload
			end
		end
	end
end

