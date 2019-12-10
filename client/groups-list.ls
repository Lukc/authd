{h} = require "maquette"

AuthWS = require "./authws.ls"

GroupList = (args) ->
	self = {
		name: "Group list"
	}

	self.render = ->
		h \div.containe [ "Group list"]

	self

module.exports = GroupList
