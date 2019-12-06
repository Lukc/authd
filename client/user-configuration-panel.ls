
{h} = require "maquette"

UserConfigurationPanel = (user, token) ->
	self = {}

	console.log user

	self.render = ->
		full-name = user.full_name
		if full-name == ""
			full-name = user.login

		h \div.columns {
			key: self
		} [
			h \div.column.is-one-quarter [
				h \figure.image.is-128 [
					h \img {
						# FIXME
						url: "https://bulma.io/images/placeholders/128x128.png"
						alt: "Avatar of #{full-name}"
					}
				]
			]
			h \div.column [
				h \div.title.is-2 [ full-name ]

				if full-name != user.login
					h \div.title.is-3.subtitle [
						user.login
					]

				h \div.title.is-4 [ "Permissions" ]
				h \div.tags user.groups.map (group) ->
					h \div.tag [ group ]
			]
		]

	self

module.exports = UserConfigurationPanel

