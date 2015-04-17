Db = require 'db'

# ========== Events ==========
# Game install
exports.onInstall = ->
	initializeColors()
	initializeGame()

# Game update 
exports.onUpgrade = !->
	# Reset values for debugging. TODO: remove
	initializeColors()
	initializeGame()

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
	request.respond 200, data || "no data"

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

initializeColors = ->
	Db.shared.set 'colors', 
		{
			'-1': {name: 'neutral', capitalizedName: 'Neutral', hex: '#C4C4C4'},
			0:    {name: 'blue',    capitalizedName: 'Blue',    hex: '#0054FF'},
			1:    {name: 'red',     capitalizedName: 'Red',     hex: '#FF3C00'},
			2:    {name: 'green',   capitalizedName: 'Green',   hex: '#009F22'},
			3:    {name: 'yellow',  capitalizedName: 'Yellow',  hex: '#F6FF00'},
			4:    {name: 'orange',  capitalizedName: 'Orange',  hex: '#FFB400'},
			5:    {name: 'purple',  capitalizedName: 'Purple',  hex: '#E700D4'}
		}

