maquette = require "maquette"

{h} = maquette

bulma = require "./bulma.ls"

AuthWS = require "./authws.ls"

LoginForm = (args) ->
	args or= {}

	self = {
		on-login: args.on-login || ->
		on-error: args.on-error || ->
		current-view: "login"

		enable-registration: args.enable-registration || false
		registrating: false

		input: {
			login: ""
			password: ""
			repeat-password: ""
		}
		locked-input: false

		error: void

		authws-url: args.authws-url ||
			((if location.protocol == 'https' then 'wss' else 'ws') +
			'://' + location.hostname + ":9999/auth.JSON")
	}


	auth-ws = AuthWS self.authws-url

	auth-ws.user-on-socket-error.push (...) ->
		self.error = "socket error"
		self.on-error ...

	auth-ws.add-event-listener \token, (message) ->
		self.error := void

		self.token = message.token
		self.locked-input := false

		if self.user
			self.on-login self.user, self.token

	auth-ws.add-event-listener \user, (message) ->
		self.error := void

		self.user = message.user

		if self.token
			self.on-login self.user, self.token

	auth-ws.add-event-listener \user-added, (message) ->
		{login, password} = {self.input.login, self.input.password}

		console.log "user added, duh"

		self.user := message.user

		auth-ws.get-token login, password

	auth-ws.add-event-listener \error, (message) ->
		# We’ll get another error that’s clearer. Dropping that one.
		if message.reason == "user not found"
			return

		self.error := message.reason
		self.locked-input := false

		self.on-error message.reason

	self.render = ->
		if self.error == "socket error"
			return h \div.notification.is-danger [
				h \div.title.is-4 [ "WebSocket error!" ]
				h \p [ "Cannot connect to authd." ]
			]

		h \form.form.login-form {
			key: self
			onsubmit: (e) ->
				{login, password} = {self.input.login, self.input.password}

				self.locked-input := true

				if self.registrating
					auth-ws.register login, password
				else
					auth-ws.get-token login, password
					auth-ws.get-user-by-credentials login, password

				e.prevent-default!
		}, [
			h \div.field {key: \login} [
				bulma.label "Login"
				bulma.input {
					type: "text"
					id: "login"
					name: "login"
					classes: {
						"is-danger": self.error == "invalid credentials"
					}
					disabled: self.locked-input
					oninput: (e) ->
						self.input.login = e.target.value
				}
			]

			h \div.field {key: \password} [
				bulma.label "Password"
				bulma.input {
					type: "password"
					id: "password"
					name: "password"
					classes: {
						"is-danger": self.error == "invalid credentials"
					}
					oninput: (e) ->
						self.input.password = e.target.value
					disabled: self.locked-input
				}
			]

			if self.registrating
				h \div.field {key: \password-repeat} [
					bulma.label "Password (reapeat)"
					bulma.input {
						type: \password
						id: \password-repeat
						name: \password-repeat
						classes: {
							"is-danger": self.input.password != self.input.repeat-password
						}
						disabled: self.locked-input
						oninput: (e) ->
							self.input.repeat-password = e.target.value
					}
				]

			if self.error
				h \div.field {key: \error-notification} [
					h \div.notification.is-danger [
						self.error
					]
				]

			if self.registrating
				h \div.field.is-grouped {key: \login-button} [
					if self.input.login == ""
						h \button.button.is-static.is-fullwidth {
							type: \submit
						} [
							"(empty login)"
						]
					else if self.input.password != self.input.repeat-password
						h \button.button.is-static.is-fullwidth {
							type: \submit
						} [
							"(passwords don’t match)"
						]
					else if self.input.password == ""
						h \button.button.is-static.is-fullwidth {
							type: \submit
						} [
							"(empty password)"
						]
					else
						h \button.button.is-success.is-fullwidth {
							type: \submit
						} [
							"Register!"
						]
				]
			else
				h \div.field.is-grouped {key: \login-button} [
					h \button.button.is-fullwidth.is-success {
						type: \submit
					} [
						"Log in!"
					]
				]

			h \div.field.level {key: \extra-buttons} [
				#h \div.level-left [
				#	h \a.link [ "(lala, remember me?)" ]
				#]

				if self.enable-registration
					h \div.level-right [
						if self.registrating
							h \a.link {
								onclick: (e) ->
									self.registrating := false
							} [
								"Log in"
							]
						else
							h \a.link {
								onclick: (e) ->
									self.registrating := true
							} [
								"Create account!"
							]
					]
			]
		]

	self

module.exports = LoginForm

