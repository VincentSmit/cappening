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
	userIds = Plugin.userIds()
	teams = Db.shared.get('numberOfTeams')
	teams = 3
	team = 0
	while(userIds.length > 0)
		randomNumber = Math.floor(Math.random() * userIds.length)
		Db.shared.set 'game', 'teams', team, 'users', Plugin.userName(userIds[randomNumber]), 'userScore', 0
		log 'team', team, 'has player', Plugin.userName(userIds[randomNumber]) 
		userIds.splice(randomNumber,1)
		team++
		team = 0 if team >= teams
		
		
			

# ========== Functions ==========
# Setup an empty game
initializeGame = ->
	Db.shared.set 'game', 'flags', {}
	Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}}
	Db.shared.set 'gameState', 0
	Db.shared.set 'game', 'teams', {}



