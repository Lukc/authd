require "json"

require "jwt"

require "ipc"

require "./user.cr"

class AuthD::Response
	include JSON::Serializable

	annotation MessageType
	end

	class_getter type = -1
	def type
		@@type
	end

	macro inherited
		def self.type
			::AuthD::Response::Type::{{ @type.name.split("::").last.id }}
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

	class Error < Response
		property reason : String?

		initialize :reason
	end

	class Token < Response
		property token  : String

		initialize :token
	end

	class User < Response
		property user   : Passwd::User

		initialize :user
	end

	class UserAdded < Response
		property user   : Passwd::User

		initialize :user
	end

	class UserEdited < Response
		property uid    : Int32

		initialize :uid
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

	def self.from_ipc(message : IPC::Message) : Response?
		payload = String.new message.payload
		type = Type.new message.type.to_i

		requests.find(&.type.==(type)).try &.from_json(payload)
	rescue e : JSON::ParseException
		raise Exception.new "malformed request"
	end
end

class IPC::Connection
	def send(response : AuthD::Response)
		send response.type.to_u8, response.to_json
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

	class Request::Register < Request
		property login      : String
		property password   : String

		initialize :login, :password
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

	def self.from_ipc(message : IPC::Message) : Request?
		payload = String.new message.payload
		type = Type.new message.type.to_i

		requests.find(&.type.==(type)).try &.from_json(payload)
	rescue e : JSON::ParseException
		raise Exception.new "malformed request"
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

			response = Response.from_ipc read

			if response.is_a?(Response::Token)
				response.token
			else
				nil
			end
		end

		def get_user?(login : String, password : String) : Passwd::User?
			send Request::GetUserByCredentials.new login, password

			response = Response.from_ipc read

			if response.is_a? Response::User
				response.user
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

			response = Response.from_ipc read

			case response
			when Response::UserAdded
				response.user
			when Response::Error
				Exception.new response.reason
			else
				# Should not happen in serialized connections, but…
				# it’ll happen if you run several requests at once.
				Exception.new
			end
		end

		def mod_user(uid : Int32, password : String? = nil, avatar : String? = nil) : Bool | Exception
			request = Request::ModUser.new @key, uid

			request.password = password if password
			request.avatar   = avatar   if avatar

			send request

			response = Response.from_ipc read

			case response
			when Response::UserEdited
				true
			when Response::Error
				Exception.new response.reason
			else
				Exception.new "???"
			end
		end
	end
end

