{h} = require "maquette"

AuthWS = require "./authws.ls"

UserAdminPanel = (args) ->
	self = {
		token: args.token
		authws-url: args.authws-url
		on-logout: args.on-logout || ->
		on-model-update: args.on-model-update || ->
		users: []
		tabs: args.tabs
		tab: args.tab || 0
	}

	authws = AuthWS self.authws-url

	self.render = ->
		h \div.section [
			h \div.tabs [
				h \ul [
					for i from 0 to (self.tabs.length - 1)
						if i == self.tab
						then h \li.is-active [
							h \a [self.tabs.[i].name]]
						else h \li [
							h \a {
								val : i
								onclick: (e) -> self.tab = e.target.val
							} [self.tabs[i].name]
						]
				]
			]
			self.tabs[self.tab].render!
			h \div.button {
				onclick: ->
					self.on-logout!
					self.on-model-update!
			} [
				"Log out"
			]
		]

	self

module.exports = UserAdminPanel

