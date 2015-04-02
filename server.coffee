Db = require 'db'

exports.onInstall = ->

exports.onUpgrade = !->
	# Reset flags to keep a clean debug environment
	Db.shared.set 'flags'
	
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.set 'flags', location.lat.toString()+'_'+location.lng.toString(), {location: location}

exports.onHttp = (request) ->
	if (data = request.data)?
		Db.shared.set 'http', data
	else
		data = Db.shared.get('http')
	request.respond 200, data || "no data"
	

