Db = require 'db'

# Events
exports.onInstall = ->
	Db.shared.set 'game', 'flags', {}
	Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}}
	Db.shared.set 'gameState', 0

exports.onUpgrade = !->
	# Reset values for debugging
	Db.shared.set 'game', 'flags', {}
	Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}}
	Db.shared.set 'gameState', 0

exports.onHttp = (request) ->
	if (data = request.data)?
		Db.shared.set 'http', data
	else
		data = Db.shared.get('http')
	request.respond 200, data || "no data"

# Client calls
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.set 'game', 'flags', location.lat.toString()+'_'+location.lng.toString(), {location: location}

exports.client_setupBasic = (roundTime, numberOfTeams) ->
	log 'setup of basic settings received: roundTime=' + roundTime + ", numberOfTeams=" + numberOfTeams
	Db.shared.set 'game', 'roundTime', roundTime
	Db.shared.set 'game', 'numberOfTeams', numberOfTeams

exports.client_setBounds = (one, two) ->
	Db.shared.set 'game', 'bounds', {one: one, two: two}
	
exports.client_startGame = ->
	Db.shared.set 'gameState', 1

# Functions


