
h = require 'maquette' .h

module.exports = {
	box: (args, children) ->
		h \div.box args, children
	title: (level, args, label) ->
		if not label
			label = args
			args = {}

		h "div.title.is-#{level}", args, [label]
	label: (args, label) ->
		if not label
			label = args
			args = {}

		h \label.label args, [label]
	input: (args, children) ->
		h \input.input args, children

	# FIXME: Use only args and add args.label and args.input?
	#        Or maybe args.name and args.type could be used directly?
	field: (args, children) ->
		h \div.field args, children

	modal: (args, content) ->
		h \div.modal args, [
			h \div.modal-background args.background
			h \div.modal-content [args.content]
		]

	form: (method, url, content) ->
		h \form.form {
			action: url
			method: method
		}, content
}

