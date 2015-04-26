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
		Db.shared.set 'game', 'teams', team, 'users', userIds[randomNumber], 'userScore', 0
		Db.shared.set 'game', 'teams', team, 'users', userIds[randomNumber], 'userName', Plugin.userName(userIds[randomNumber])
		log 'team', team, 'has player', Plugin.userName(userIds[randomNumber]) 
		userIds.splice(randomNumber,1)
		team++
		team = 0 if team >= teams

# Checkin location for capturing a flag		
exports.client_checkinLocation = (client, location) ->
	log 'checkinLocation() client: ', client, ', location: lat=', location.lat, ', lng=', location.lng
	flags = Db.shared.ref('game', 'flags')
	beaconRadius = Db.shared.peek('game', 'beaconRadius')
	flags.iterate (flag) ->
		current = flag.get('inRange', client)?
		flagDistance = distance(location.lat, location.lng, flag.peek('location', 'lat'), flag.peek('location', 'lng'))
		newStatus = flagDistance < beaconRadius
		#log 'flagLoop: flag=', flag, ', beaconRadius=', beaconRadius, ', distance=', flagDistance, ', current=', current, ', new=', newStatus
		if newStatus != current
			if newStatus
				log 'Adding to inRange'
				flag.set 'inRange', client, 'true'
				# START debug code
				log 'beacon ', flag.n, ' captured by team ', getTeamOfUser(client), ' by user ', client
				flag.set 'owner', getTeamOfUser(client)
				# END debug code

				# Start takeover
			else
				log 'Removed from inRange'
				# clean takeover
				flag.remove 'inRange', client


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

# Calculate distance
distance = (inputLat1, inputLng1, inputLat2, inputLng2) ->
	r = 6378137
	rad = Math.PI / 180
	lat1 = inputLat1 * rad
	lat2 = inputLat2 * rad
	a = Math.sin(lat1) * Math.sin(lat2) + Math.cos(lat1) * Math.cos(lat2) * Math.cos((inputLng2 - inputLng1) * rad);
	return r * Math.acos(Math.min(a, 1));

# Get the team id the user is added to
getTeamOfUser = (userId) ->
	result = -1
	Db.shared.iterate 'game', 'teams', (team) !->
		if team.peek('users', userId, 'userName')?
			result = team.n
	#if result is -1
	#	log 'Warning: Did not find team for userId=', userId
	return result



