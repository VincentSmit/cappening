Db = require 'db'
Plugin = require 'plugin'

# ========== Events ==========
# Game install
exports.onInstall = ->
	initializeGame()

# Game update 
exports.onUpgrade = !->
	# Reset values for debugging. TODO: remove
	initializeGame()
	# Reset flags to keep a clean debug environment
	Db.shared.set 'flags'
	
exports.client_makeTeams = ->
	teams[4]
	playerArray[Plugin.users.count().get()]
	for i in [0..teams.length] by 1
		teams[i].set
			name: i+1  #teamnaam en referentie naar teamkleur
			players: playerArray #lege lijst waar spelers over verdeeld worden
	Db.shared.set 'teams', teams
	
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.set 'flags', location.lat.toString()+'_'+location.lng.toString(), {location: location}

# Config changes (by admin or plugin adder)
exports.onConfig = (config) !->
	if config.restart
		log 'Restarting game'
		initializeGame()

# No idea
exports.onHttp = (request) ->
	if (data = request.data)?
		Db.shared.set 'http', data
	else
		data = Db.shared.get('http')
	request.respond 200, data || 'no data'
	
#========== Client calls ==========
# Add a flag (during setup phase)
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.set 'game', 'flags', location.lat.toString()+'_'+location.lng.toString(), {location: location}
	Db.shared.set 'game', 'flags', location.lat.toString()+'_'+location.lng.toString(), 'owner', -1 

# Set the round time and number of teams
exports.client_setupBasic = (roundTime, numberOfTeams) ->
	log 'setup of basic settings received: roundTime=' + roundTime + ", numberOfTeams=" + numberOfTeams
	Db.shared.set 'game', 'roundTime', roundTime
	Db.shared.set 'game', 'numberOfTeams', numberOfTeams

# Set the game boundaries
exports.client_setBounds = (one, two) ->
	Db.shared.set 'game', 'bounds', {one: one, two: two}

# Start the game
exports.client_startGame = ->
	Db.shared.set 'gameState', 1

# ========== Functions ==========
# Setup an empty game
initializeGame = ->
	Db.shared.set 'game', 'flags', {}
	Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}}
	Db.shared.set 'gameState', 0


