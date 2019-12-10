{h} = require "maquette"

AuthWS = require "./authws.ls"

UserList = (args) ->
	self = {
		name: "Users list"
		token: args.token
		authws-url: args.authws-url
		on-model-update: args.on-model-update || ->
		users: []
	}

	authws = AuthWS self.authws-url

	authws.socket.onopen = ->
		authws.list-users self.token

	authws.add-event-listener \users-list (message) ->
		self.users = message.users

		self.on-model-update!

	self.render = ->
			h \div.container [
				h \table.table.is-fullwidth [
					h \thead [
						h \tr [
							h \th [ "Login" ]
							h \th [ "UID" ]
							h \th [ "GID" ]
						]
					]
					h \tbody [
						for user in self.users
							h \tr {key: user.uid} [
								h \td [
									user.login
								]
								h \td [
									user.uid.toString!
								]
								h \td [
									user.gid.toString!
								]
							]
					]
				]
			]

	self

module.exports = UserList
