# This code has been written by happening for the betrayal plugin, see: https://github.com/Happening/Betrayal/
Obs = require 'obs'
Dom = require 'dom'
Form = require 'form'
Colors = require('plugin').colors()

# The time input is kind of special, as it doesn't have a no-state value. So if the value wasn't set, a change is triggered immediately.
exports.render = render = (opts) ->
	opts = {} if typeof opts!='object'
	if opts.onSave
		return Form.editInModal(opts,render)

	sanitize = opts.normalize = (v) ->
		v = 0|v
		if v<opts.min
			v = opts.max
		else if v>opts.max
			v = opts.min
		else
			v

	[handleChange,orgValue] = Form.makeInput opts
	obsVal = Obs.create orgValue
	Obs.observe !->
		handleChange obsVal.get()

	renderArrow = (dir) !->
		Dom.div !->
			Dom.style
				width: 0
				height: 0
				borderStyle: "solid"
				borderWidth: "#{if dir>0 then 0 else 20}px 20px #{if dir>0 then 20 else 0}px 20px"
				borderColor: "#{if dir>0 then 'transparent' else Colors.highlight} transparent #{if dir>0 then Colors.highlight else Colors.highlight} transparent"
			Dom.onTap !->
				obsVal.set sanitize(obsVal.peek()+dir)

	Dom.div !->
		Dom.style Box: "vertical center"
		renderArrow opts.step||1
		Dom.input !->
			inputE = Dom.get()
			val = ''+obsVal.get()
			while val.length < opts.minDigits
				val = '0'+val
			Dom.prop
				size: opts.digits||opts.minDigits||3
				value: val
			Dom.style
				fontFamily: 'monospace'
				fontSize: '30px'
				fontWeight: 'bold'
				textAlign: 'center'
				border: 'inherit'
				backgroundColor: 'inherit'
				color: 'inherit'
			Dom.on 'input change', !-> obsVal.set sanitize(inputE.value())
			Dom.on 'click', !-> inputE.select()
		renderArrow -(opts.step||1)