maquette = require "maquette"

{create-projector, h} = maquette

projector = create-projector!

bulma = require "./bulma.ls"

AuthWS = require "./authws.ls"

LoginForm = require "./login-form.ls"
UserConfigurationPanel = require "./user-configuration-panel.ls"

model = {
	token: void
}

document.add-event-listener \DOMContentLoaded ->
	user-config-panel = void

	login-form = LoginForm {
		enable-registration: true
		authws-url: "ws://localhost:9999/auth.JSON"

		on-login: (user, token) ->
			model.user := user
			model.token := token

			user-config-panel := UserConfigurationPanel model.user, model.token

			projector.schedule-render!
		on-error: (error) ->
			projector.schedule-render!
	}

	projector.append document.body, ->
		h \div.body [
			if model.token == void
				h \div.section.hero.is-fullheight [
					h \div.hero-body [
						h \div.container [
							h \div.columns [
								h \div.column []
								h \div.column.is-3 [
									login-form.render!
								]
								h \div.column []
							]
						]
					]
				]
			else if user-config-panel
				h \div.section [
					h \div.container [
						h \div.box [
							user-config-panel.render!
						]
					]
				]
		]


