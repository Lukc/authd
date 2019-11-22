require "json"

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
end

class AuthD::Request
	include JSON::Serializable

	annotation MessageType
	end

	class_getter type = -1

	macro inherited
		def self.type
			::AuthD::Request::Type::{{ @type.name.split("::").last.id }}
		end
	end

	macro initialize(*properties)
		def initialize(
			{% for value in properties %}
				@{{value.id}}{% if value != properties.last %},{% end %}
			{% end %}
		)
		end

		def type
			Type::{{ @type.name.split("::").last.id }}
		end
	end

	class GetToken < Request
		property login      : String
		property password   : String

		initialize :login, :password
	end

	class AddUser < Request
		# Only clients that have the right shared key will be allowed
		# to create users.
		property shared_key : String

		property login      : String
		property password   : String
		property uid        : Int32?
		property gid        : Int32?
		property home       : String?
		property shell      : String?

		initialize :shared_key, :login, :password
	end

	class GetUser < Request
		property uid        : Int32

		initialize :uid
	end

	class GetUserByCredentials < Request
		property login      : String
		property password   : String

		initialize :login, :password
	end

	class ModUser < Request
		property shared_key : String

		property uid        : Int32
		property password   : String?
		property avatar     : String?

		initialize :shared_key, :uid
	end

	# This creates a Request::Type enumeration. One entry for each request type.
	{% begin %}
		enum Type
			{% for ivar in @type.subclasses %}
				{% klass = ivar.name %}
				{% name = ivar.name.split("::").last.id %}

				{% a = ivar.annotation(MessageType) %}

				{% if a %}
					{% value = a[0] %}
					{{ name }} = {{ value }}
				{% else %}
					{{ name }}
				{% end %}
			{% end %}
		end
	{% end %}

	# This is an array of all requests types.
	{% begin %}
		class_getter requests = [
			{% for ivar in @type.subclasses %}
				{% klass = ivar.name %}

				{{klass}},
			{% end %}
		]
	{% end %}

	def self.from_ipc(message : IPC::Message)
		payload = String.new message.payload
		type = Type.new message.type.to_i

		begin
			request = requests.find(&.type.==(type)).try &.from_json(payload)
		rescue e : JSON::ParseException
			raise Exception.new "misformed request"
		end

		request
	end
end

class IPC::Connection
	def send(request : AuthD::Request)
		send request.type.to_u8, request.to_json
	end
end

module AuthD
	class Client < IPC::Connection
		property key : String

		def initialize
			@key = ""

			initialize "auth"
		end

		def get_token?(login : String, password : String) : String?
			send Request::GetToken.new login, password

			response = read

			if response.type == Response::Type::Ok.value.to_u8
				String.new response.payload
			else
				nil
			end
		end

		def get_user?(login : String, password : String) : Passwd::User?
			send Request::GetUserByCredentials.new login, password

			response = read

			if response.type == Response::Type::Ok.value.to_u8
				Passwd::User.from_json String.new response.payload
			else
				nil
			end
		end

		def get_user?(uid : Int32)
			send Request::GetUser.new uid

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
			send Request::AddUser.new @key, login, password

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
			request = Request::ModUser.new @key, uid

			request.password = password if password
			request.avatar   = avatar   if avatar

			send request

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

