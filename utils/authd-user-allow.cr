require "option_parser"

require "../src/authd.cr"

key_file : String?     = nil
login : String?    = nil
service : String?  = nil
resource : String? = nil
register = false
level = AuthD::User::PermissionLevel::Read

OptionParser.parse do |parser|
	parser.unknown_args do |args|
		if args.size != 3
			puts "usage: #{PROGRAM_NAME} <user> <service> <resource> [options]"
			puts parser
			exit 1
		end

		login, service, resource = args
	end

	parser.on "-K file", "--key-file file", "Read the authd shared key from a file." do |file|
		key_file = file
	end

	parser.on "-L level", "--level level", "Sets the permission level to give the user." do |l|
		begin
			level = AuthD::User::PermissionLevel.parse l
		rescue
			STDERR.puts "Could not parse permission level '#{l}'"
			exit 1
		end
	end

	parser.on "-R", "--register", "Use a registration request instead of a add-user one." do
		register = true
	end

	parser.on "-h", "--help", "Prints this help message." do
		puts "usage: #{PROGRAM_NAME} <user> <service> <resource> [options]"
		puts parser
		exit 0
	end
end

if key_file.nil?
	STDERR.puts "you need to provide the shared key"
	exit 1
end

authd = AuthD::Client.new

authd.key = File.read(key_file.not_nil!).chomp

begin
	user = authd.get_user? login.not_nil!

	if user.nil?
		raise AuthD::Exception.new "#{login}: no such user"
	end

	# FIXME: make a “disallow” variant.
	authd.set_permission user.uid, service.not_nil!, resource.not_nil!, level
rescue e : AuthD::Exception
	puts "error: #{e.message}"
end

authd.close

