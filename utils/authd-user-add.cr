require "option_parser"

require "../src/authd.cr"

key_file : String?     = nil
cli_login : String?   = nil
profile_file : String? = nil
register = false
email = nil
phone = nil

OptionParser.parse do |parser|
	parser.unknown_args do |args|
		if args.size == 0 || args.size > 3
			puts "usage: #{PROGRAM_NAME} <login> <email> <phone> [options]"
			puts parser
			exit 1
		end

		puts "coucou"
		pp! args

		cli_login, email, phone = args[0..2]
	end

	parser.on "-p file", "--profile file", "Read the user profile from a file." do |file|
		profile_file = file
	end

	parser.on "-K file", "--key-file file", "Read the authd shared key from a file." do |file|
		key_file = file
	end

	parser.on "-R", "--register", "Use a registration request instead of a add-user one." do
		register = true
	end

	parser.on "-h", "--help", "Prints this help message." do
		puts "usage: #{PROGRAM_NAME} <login> <email> <phone> [options]"
		puts parser
		exit 0
	end
end

if cli_login.nil?
	STDERR.puts "no login provided"
	exit 1
end

login = cli_login.not_nil! # not_nil!? O RLY?

profile = profile_file.try do |file|
	begin
		JSON.parse File.read file
	rescue e
		STDERR.puts e.message
		exit 1
	end
end

STDOUT << "password: "
STDOUT << `stty -echo`
STDOUT.flush
password = STDIN.gets.try &.chomp

STDOUT << '\n'
STDOUT << `stty echo`

exit 1 unless password

authd = AuthD::Client.new

email = nil if email == ""
phone = nil if phone == ""

begin
	if register
		pp! authd.register login, password, email, phone, profile: profile
	else
		key_file.try do |file| # FIXME: fail if missing?
			authd.key = File.read(file).chomp
		end

		pp! authd.add_user login, password, email, phone, profile: profile
	end
rescue e : AuthD::Exception
	puts "error: #{e.message}"
end

authd.close

