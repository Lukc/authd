bulma = require "./bulma.ls"
h = require 'maquette' .h

AuthWS = (socket-url) ->
	self = {}

	request-types = {
		"get-token":               0
		"add-user":                1
		"get-user":                2
		"get-user-by-credentials": 3
		"mod-user":                4
		"register":                5
		"get-extra":               6
		"set-extra":               7
	}

	response-types = {
		"error":                   0
		"token":                   1
		"user":                    2
		"user-added":              3
		"user-edited":             4
		"extra":                   5
		"extra-updated":           6
	}

	# TODO: naming convention
	# users can record functions to run on events
	self.user-on-socket-error = []
	self.user-on-socket-close = []

	self.callbacks = {}
	for key, value of response-types
		self.callbacks[value] = []

	self.add-event-listener = (type, callback) ->
		type = response-types[type]

		self.callbacks[type] ++= [callback]

	self.open-socket = ->
		self.socket := new WebSocket socket-url

		self.socket.onerror = (event) ->
			for f in self.user-on-socket-error
				f event
			self.socket.close!

		self.socket.onclose = (event) ->
			for f in self.user-on-socket-close
				f event

		self.socket.onmessage = (event) ->
			message = JSON.parse(event.data)

			for f in self.callbacks[message.mtype]
				f JSON.parse(message.payload)

	self.reopen = ->
		self.socket.close!
		self.open-socket!

	self.open-socket!

	self.send = (type, opts) ->
		self.socket.send JSON.stringify { mtype: type, payload: opts }

	self.get-token = (login, password) ->
		self.send request-types[\get-token], JSON.stringify {
			login: login
			password: password
		}

	self.get-user-by-credentials = (login, password) ->
		self.send request-types[\get-user-by-credentials], JSON.stringify {
			login: login
			password: password
		}

	self.login = (login, password) ->
		self.get-token login, password
		self.get-user-by-credentials login, password


	self.get-user = (uid) ->
		self.send request-types[\get-user], JSON.stringify {
			uid: uid
		}

	self.register = (login, password) ->
		self.send request-types[\register], JSON.stringify {
			login: login
			password: password
		}

	self.get-extra = (token, name) ->
		self.send request-types[\get-extra], JSON.stringify {
			token: token
			name: name
		}

	self.set-extra = (token, name, extra) ->
		self.send request-types[\set-extra], JSON.stringify {
			token: token
			name: name
			extra: extra
		}

	# TODO: authd overhaul required
	#self.add-user = (login, password) ->
	#	self.send request-types[\add-user], JSON.stringify {
	#		login: login
	#		password: password
	#	}

	# TODO: authd overhaul required
	#self.mod-user = (uid) ->
	#	self.send request-types[\mod-user], JSON.stringify {
	#		uid: uid
	#	}

	self

module.exports = AuthWS

