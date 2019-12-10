maquette = require "maquette"

{create-projector, h} = maquette

projector = create-projector!

bulma = require "./bulma.ls"

AuthWS = require "./authws.ls"

LoginForm = require "./login-form.ls"
UserConfigurationPanel = require "./user-configuration-panel.ls"
UserAdminPanel = require "./user-admin-panel.ls"
UsersList = require "./user-list.ls"
GroupsList = require "./groups-list.ls"

model = {
	token: void
}

authws-url = "ws://localhost:9999/auth.JSON"

document.add-event-listener \DOMContentLoaded ->
	user-config-panel = void
	user-admin-panel  = void

	login-form = LoginForm {
		enable-registration: true
		authws-url: authws-url

		on-login: (user, token) ->
			model.user := user
			model.token := token

			if user.groups.find (== "authd")
				tabs = [
					UsersList {
						token: model.token
						authws-url: authws-url
						on-model-update: ->
							projector.schedule-render!
					}
					GroupsList {}
				]
				user-admin-panel := UserAdminPanel {
					authws-url: authws-url
					user: model.user
					token: model.token
					tabs: tabs

					on-model-update: ->
						projector.schedule-render!
					on-logout: ->
						model.token := void
						model.user := void
				}
			else
				user-config-panel := UserConfigurationPanel {
					authws-url: authws-url
					user: model.user
					token: model.token

					on-model-update: ->
						projector.schedule-render!
					on-logout: ->
						model.token := void
						model.user := void
				}

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
						user-config-panel.render!
					]
				]
			else if user-admin-panel
				h \div.section [
					h \div.container [
						user-admin-panel.render!
					]
				]
		]

