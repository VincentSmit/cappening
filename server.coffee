Db = require 'db'
Plugin = require 'plugin'

# ========== Events ==========
# Game install
exports.onInstall = ->
	initializeColors()
	initializeGame()

# Game update 
exports.onUpgrade = !->
	# Reset values for debugging. TODO: remove
	Db.shared.set {}
	
	initializeColors()
	initializeGame()

# Config changes (by admin or plugin adder)
exports.onConfig = (config) !->
	if config.restart
		log 'Restarting game'
		initializeGame()
	

#========== Client calls ==========
# Add a flag (during setup phase)
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.set 'game', 'flags', location.lat.toString()+'_'+location.lng.toString(), {location: location}
	Db.shared.set 'game', 'flags', location.lat.toString()+'_'+location.lng.toString(), 'owner', -1 

# Set the round time unit and number
exports.client_setRoundTime = (roundTimeNumber, roundTimeUnit) ->
	log 'RoundTime set to: ' + roundTimeNumber + ' ' + roundTimeUnit
	Db.shared.set 'game', 'roundTimeNumber', roundTimeNumber
	Db.shared.set 'game', 'roundTimeUnit', roundTimeUnit

# Set the number of teams
exports.client_setTeams = (teams) ->
	log 'Teams set to: ', teams
	Db.shared.set 'game', 'numberOfTeams', teams

# Set the game boundaries
exports.client_setBounds = (one, two) ->
	Db.shared.set 'game', 'bounds', {one: one, two: two}

# Start the game
exports.client_startGame = ->
	Db.shared.set 'gameState', 1
	userIds = Plugin.userIds()
	teams = Db.shared.get('game','numberOfTeams')
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
	Db.shared.set 'gameState', 0
	Db.shared.set 'game', {}
	Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}}
	Db.shared.set 'game', 'numberOfTeams', 2
	Db.shared.set 'game', 'beaconRadius', 200
	Db.shared.set 'game', 'roundTimeUnit', 'Days'
	Db.shared.set 'game', 'roundTimeNumber', 7

initializeColors = ->
	Db.shared.set 'colors', 
		{
			'-1': {name: 'neutral', capitalizedName: 'Neutral', hex: '#999999'},
			0:    {name: 'blue',    capitalizedName: 'Blue',    hex: '#3882b6'},
			1:    {name: 'red',     capitalizedName: 'Red',     hex: '#FF3C00'},
			2:    {name: 'green',   capitalizedName: 'Green',   hex: '#009F22'},
			3:    {name: 'yellow',  capitalizedName: 'Yellow',  hex: '#F6FF00'},
			4:    {name: 'orange',  capitalizedName: 'Orange',  hex: '#FFB400'},
			5:    {name: 'purple',  capitalizedName: 'Purple',  hex: '#E700D4'}
		}


