require "option_parser"

require "../src/authd.cr"

key_file  : String? = nil
cli_login : String? = nil

OptionParser.parse do |parser|
	parser.unknown_args do |args|
		if args.size != 1
			puts "usage: #{PROGRAM_NAME} <login> [options]"
			puts parser
			exit 1
		end

		cli_login = args[0]
	end

	parser.on "-K file", "--key-file file", "Read the authd shared key from a file." do |file|
		key_file = file
	end

	parser.on "-h", "--help", "Prints this help message." do
		puts "usage: #{PROGRAM_NAME} <login> [options]"
		puts parser
		exit 0
	end
end

begin
	authd = IPC::Connection.new "auth"

	authd = AuthD::Client.new
	authd.key = File.read(key_file.not_nil!).chomp

	login = cli_login.not_nil!

	# AskPasswordRecovery => PasswordRecoverySent
	# PasswordRecovery => 

	pp! authd.ask_password_recovery login
rescue e
	puts "Error: #{e}"
	exit 1
end
