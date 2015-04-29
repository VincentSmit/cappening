Db = require 'db'
Plugin = require 'plugin'

# ========== Events ==========
# Game install
exports.onInstall = ->
	initializeColors()
	initializeGame()

# Game update 
exports.onUpgrade = !->	
	initializeColors()
	initializeGame()

# Config changes (by admin or plugin adder)
exports.onConfig = (config) !->
	if config.restart
		log 'Restarting game'
		initializeGame()
	

#========== Client calls ==========
# Add a beacon (during setup phase)
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.set 'game', 'beacons', location.lat.toString()+'_'+location.lng.toString(), {location: location}
	Db.shared.set 'game', 'beacons', location.lat.toString()+'_'+location.lng.toString(), 'owner', -1 

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
	Db.shared.set 'gameState', 1 # Set gameState at the end, because this triggers a repaint at the client so we want all data prepared before that

# Checkin location for capturing a beacon		
exports.client_checkinLocation = (client, location) ->
	if Db.shared.get 'gameState' is not 1
		log 'Client ', client, ' (', Plugin.userName(client), ') tried to capture beacon while game is not running!'
	else
		log 'checkinLocation() client: ', client, ', location: lat=', location.lat, ', lng=', location.lng
		beacons = Db.shared.ref('game', 'beacons')
		beaconRadius = Db.shared.peek('game', 'beaconRadius')
		beacons.iterate (beacon) ->
			current = beacon.get('inRange', client)?
			beaconDistance = distance(location.lat, location.lng, beacon.peek('location', 'lat'), beacon.peek('location', 'lng'))
			newStatus = beaconDistance < beaconRadius
			#log 'beaconLoop: beacon=', beacon, ', beaconRadius=', beaconRadius, ', distance=', beaconDistance, ', current=', current, ', new=', newStatus
			if newStatus != current
				if newStatus
					log 'Adding to inRange: id=', client, ', name=', Plugin.userName(client)
					beacon.set 'inRange', client, 'true'

					# TODO
					# 1: Determine how much players of each team are in range
					# 2: Determine if there is progress and which team
					# 3: Determine if it is 'neutralizing' or 'capturing'
					# 4: Determine the speed of the capture
					# 5: Set the current percentage of the flag to the correct state by doing 1-4 for the previous team state

					teamMembers = (0 for num in [0..6])
					Db.shared.iterate 'game', 'beacons', beacon.n, 'inRange', (player) !->
						team = getTeamOfUser(player.n)
						teamMembers[team] = teamMembers[team]+1
					log 'teamMembers count: ', teamMembers	



					# START debug code
					log 'beacon ', beacon.n, ' captured by team ', getTeamOfUser(client), ' by user ', client
					beacon.set 'owner', getTeamOfUser(client)
					# END debug code

					# capture event
					maxId = Db.shared.ref('game', 'eventlist').incr 'maxId'
					Db.shared.set 'game', 'eventlist', maxId, 'timestamp', new Date()/1000
					Db.shared.set 'game', 'eventlist', maxId, 'type', "capture"
					Db.shared.set 'game', 'eventlist', maxId, 'beacon', beacon.n

					# Start takeover
				else
					log 'Removed from inRange: ', client, ', name=', Plugin.userName(client)
					# clean takeover
					beacon.remove 'inRange', client


# ========== Functions ==========
# Setup an empty game
initializeGame = ->
	Db.shared.set 'gameState', 0
	Db.shared.modify 'gameNumber', (v) -> (0||v)+1
	Db.shared.set 'game', {}
	Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}}
	Db.shared.set 'game', 'numberOfTeams', 2
	Db.shared.set 'game', 'beaconRadius', 200
	Db.shared.set 'game', 'roundTimeUnit', 'Days'
	Db.shared.set 'game', 'roundTimeNumber', 7
	Db.shared.set 'game', 'eventlist', 'maxId', 0

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



