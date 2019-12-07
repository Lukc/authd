
{h} = require "maquette"

AuthWS = require "./authws.ls"

get-full-name = (self) ->
	full-name = self.profile && self.profile.full-name || ""
	if full-name == ""
		self.user.login
	else
		full-name

default-side-bar-renderer = (self) ->
	h \div { key: \side-bar } [
		h \figure.image.is-128x128.is-clipped [
			if self.profile && self.profile.avatar
				h \img {
					src: self.profile.avatar
					alt: "Avatar of #{get-full-name self}"
				}
		]
	]

default-heading-renderer = (self) ->
	full-name = get-full-name self

	h \div.section {key: \heading} [
		h \div.title.is-2 [ full-name ]

		if full-name != self.user.login
			h \div.title.is-3.subtitle [
				self.user.login
			]
	]


Fields = {
	render-text-input: (token, auth-ws, key, inputs, model) ->
		upload = ->
			console.log "clickity click", key, inputs[key], inputs
			return unless inputs[key]

			payload = {}
			for _key, value of model
				payload[_key] = value
			payload[key] = inputs[key]

			inputs[key] := void

			auth-ws.set-extra token, "profile", payload

		h \div.field.has-addons {key: key} [
			h \div.control.is-expanded [
				h \input.input {
					value: inputs[key] || model[key]
					oninput: (e) ->
						console.log "input for",key
						inputs[key] := e.target.value
				}
			]
			h \div.control [
				h \div.button {
					onclick: upload
				} [ "Update" ]
			]
		]
}

UserConfigurationPanel = (args) ->
	self = {
		user: args.user || {}
		profile: args.profile
		token: args.token
		authws-url: args.authws-url ||
			((if location.protocol == 'https' then 'wss' else 'ws') +
			'://' + location.hostname + ":9999/auth.JSON")

		side-bar-renderer: args.side-bar-renderer || default-side-bar-renderer
		heading-renderer: args.heading-renderer || default-heading-renderer

		on-model-update: args.on-model-update || ->

		model: args.model || [
			["fullName", "Full Name", "string"]
			["avatar", "Profile Picture", "image-url"]
			["email", "Mail Address", "string"]
		]

		input: {}
	}

	auth-ws = AuthWS self.authws-url

	auth-ws.add-event-listener \extra, (message) ->
		if message.name == "profile"
			console.log "got profile", message.extra
			self.profile = message.extra || {}

			self.on-model-update!

	auth-ws.add-event-listener \extra-updated, (message) ->
		if message.name == "profile"
			console.log "got profile", message.extra
			self.profile = message.extra || {}

			self.on-model-update!

	unless self.profile
		auth-ws.socket.onopen = ->
			auth-ws.get-extra self.token, "profile"

	self.render = ->
		h \div.columns {
			key: self
		} [
			h \div.column.is-narrow [
				self.side-bar-renderer self
			]
			h \div.column [
				self.heading-renderer self

				if self.profile
					h \div.box {key: \profile} [
						h \div.form [
							h \div.title.is-4 [ "Profile" ]

							for element in self.model
								[key, label, type] = element

								switch type
								when "string", "image-url"
									h \div.field { key: key } [
										h \div.label [ label ]
										Fields.render-text-input self.token, auth-ws, key, self.input, self.profile
									]
						]
					]
				else
					# FIXME: urk, ugly loader.
					h \div.button.is-loading

				h \div.box { key: \password } [
					h \div.title.is-4 [ "Password" ]
					h \div.label [ "Old #{label}" ]
					h \div.control [
						h \input.input {
							type: \password
							oninput: (e) ->
								self.input["password.old"] = e.target.value
						}
					]
					h \div.label [ "New #{label}" ]
					h \div.control [
						h \input.input {
							type: \password
							oninput: (e) ->
								self.input["password.new"] = e.target.value
						}
					]
					h \div.label [ "New #{label} (repeat)" ]
					h \div.field.has-addons [
						h \div.control.is-expanded [
							h \input.input {
								type: \password
								oninput: (e) ->
									self.input["password.new2"] = e.target.value
							}
						]
						h \div.control [
							h \div.button {
								classes: {
									"is-danger": self.input["password.new"] && self.input["password.new"] != self.input["password.new2"]
									"is-static": (!self.input["password.new"]) && self.input["password.new"] != self.input["password.new2"]
								}
								onclick: ->
									if self.input["password.new"] != self.input["password.new2"]
										return

									auth-ws.update-password self.user.login, self.input["password.old"], self.input["password.new"]

							} [ "Update" ]
						]
					]
				]

				if self.show-developer
					h \div.box {key: \passwd} [
						h \div.title.is-4 [ "Permissions" ]

						h \div.form [
							h \div.field {key: \uid} [
								h \div.label [ "User ID" ]
								h \div.control [ self.user.uid.to-string! ]
							]

							h \div.field {key: \gid} [
								h \div.label [ "Group ID" ]
								h \div.control [ self.user.gid.to-string! ]
							]

							h \div.field {key: \groups} [
								h \div.label [ "Groups" ]
								h \div.control.is-grouped [
									h \div.tags self.user.groups.map (group) ->
										h \div.tag [ group ]
								]
							]
						]
					]
				else
					h \a.is-pulled-right.is-small.has-text-grey {
						key: \passwd
						onclick: ->
							self.show-developer := true
							self.on-model-update!
					} [
						"Show developer data!"
					]
			]
		]

	self

module.exports = UserConfigurationPanel

