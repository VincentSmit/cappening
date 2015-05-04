Db = require 'db'
Plugin = require 'plugin'
Timer = require 'timer'
Event = require 'event'

# ========== Events ==========
# Game install
exports.onInstall = ->
	initializeColors()
	initializeGame()

# Game update 
exports.onUpgrade = !->	
	# Normally nothing to do here
	#initializeColors()
	#initializeGame()

# Config changes (by admin or plugin adder)
exports.onConfig = (config) !->
	if config.restart
		log 'Restarting game'
		initializeGame()
	

#========== Client calls ==========
# Add a beacon (during setup phase)
exports.client_addMarker = (location) ->
	log 'Adding marker: lat=', location.lat, ', lng=', location.lng
	nextNumber = 0
	while Db.shared.get('game', 'beacons', nextNumber)?
		nextNumber++

	Db.shared.set 'game', 'beacons', nextNumber, {location: location}
	Db.shared.set 'game', 'beacons', nextNumber, 'owner', -1 
	Db.shared.set 'game', 'beacons', nextNumber, 'nextOwner', -1
	Db.shared.set 'game', 'beacons', nextNumber, 'percentage', 0
	Db.shared.set 'game', 'beacons', nextNumber, 'captureValue', 10
	Db.shared.set 'game', 'beacons', nextNumber, 'action', "none"

exports.client_deleteMarker = (location) ->	
	#Finding the right beacon
	log 'Deleting marker: lat=', location.lat, ', lng=', location.lng
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		if beacon.get('location', 'lat') == location.lat and beacon.get('location', 'lng') == location.lng
			Db.shared.remove 'game', 'beacons', beacon.n
	
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

# Get clients ingame user ID
# exports.client_getIngameUserId = (client) ->
# 	client.reply 

# Start the game
exports.client_startGame = ->
	setTimer()
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
	Db.shared.iterate 'game', 'teams', (team) !->
		Db.shared.set 'game', 'teams', team.n, 'teamScore', 0
		Db.shared.set 'game', 'teams', team.n, 'captured', 0
		Db.shared.set 'game', 'teams', team.n, 'neutralized', 0
	Db.shared.set 'gameState', 1 # Set gameState at the end, because this triggers a repaint at the client so we want all data prepared before that
	Event.create
    	unit: 'startGame'
    	text: "The game has started!"

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
			if newStatus != current
				# Cancel timers of ongoing caputes/neutralizes (new ones will be set below if required)
				Timer.cancel 'onCapture', {beacon: beacon.n, players: getInrangePlayers(beacon.n)}
				Timer.cancel 'onNeutralize', {beacon: beacon.n, players: getInrangePlayers(beacon.n)}
				if newStatus
					owner = beacon.get 'owner'
					log 'Adding to inRange: id=', client, ', name=', Plugin.userName(client)
					beacon.set 'inRange', client, 'true'
					# Start takeover
				else
					log 'Removed from inRange: ', client, ', name=', Plugin.userName(client)
					# clean takeover
					beacon.remove 'inRange', client

				# ========== Handle changes for inRange players ==========
				# Determine members per team
				teamMembers = (0 for team in [0..5])
				Db.shared.iterate 'game', 'beacons', beacon.n, 'inRange', (player) !->
					team = getTeamOfUser(player.n)
					teamMembers[team] = teamMembers[team]+1
				log 'teamMembers count: ', teamMembers	

				# Determine who is competing
				max = 0
				competing = []
				for team in [0..5]
					if teamMembers[team] > max
						max = teamMembers[team]
						competing = []
						competing.push team
					else if teamMembers[team] == max
						competing.push team
				# Update percentage taken for current time
				updateBeaconPercentage(beacon)

				# Check if there should be progress
				if competing.length == 1
					# Team will capture the flag
					activeTeam = competing[0]
					if activeTeam != owner
						beacon.set 'nextOwner', activeTeam
						percentage = beacon.get 'percentage'
						if owner == -1
							# Capturing
							log 'Team ', activeTeam, ' is capturing beacon ', beacon.n
							beacon.set 'action', 'capture'
							beacon.set 'actionStarted', new Date()/1000
							# Set timer for capturing
							playersStr = getInrangePlayers(beacon.n)
							Timer.set (100-percentage)*10*30, 'onCapture', {beacon: beacon.n, players: playersStr}
						else
							# Neutralizing
							log 'Team ', activeTeam, ' is neutralizing beacon ', beacon.n
							beacon.set 'action', 'neutralize'
							beacon.set 'actionStarted', new Date()/1000

							playersStr = getInrangePlayers(beacon.n)
							Timer.set percentage*10*30, 'onNeutralize', {beacon: beacon.n, players: playersStr}
					else
						log 'activeteam already has the beacon, ', activeTeam, '=', owner

				else if competing.length > 1 or competing.length is 0
					# No progess, stand-off
					beacon.set 'action', 'none'
					beacon.set 'actionStarted', new Date()
					if competing.length > 1
						log 'Capture of beacon ', beacon.n, ' on hold, competing teams: ', competing
					else
						log 'Capture of beacon ', beacon.n, ' stopped, left the area'

# Update the takeover percentage of a beacon depening on current action and the passed time
updateBeaconPercentage = (beacon) !->
	currentPercentage = beacon.get 'percentage'
	action = beacon.get 'action'
	actionStarted = beacon.get 'actionStarted'
	if action is 'capture'
		time = (new Date()/1000)-actionStarted
		newPercentage = currentPercentage+(time/30*100)
		newPercentage = 100 if newPercentage>100
		beacon.set 'percentage', newPercentage
	else if action is 'neutralize'
		time = (new Date()/1000)-actionStarted
		newPercentage = currentPercentage-(time/30*100)
		newPercentage = 0 if newPercentage<0
		beacon.set 'percentage', newPercentage


# Called by the beacon capture timer
exports.onCapture = (args) !->
	log 'args=', args
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	nextOwner = beacon.get('nextOwner')
	log 'Team ', nextOwner, ' has captured beacon ', beacon.n, ', players: ', args.players
	beacon.set 'percentage', 100
	beacon.set 'owner', nextOwner
	beacon.set 'action', 'none'
	beacon.set 'actionStarted', new Date()/1000

	# Add event log entrie(s)
	maxId = Db.shared.ref('game', 'eventlist').incr 'maxId'
	Db.shared.set 'game', 'eventlist', maxId, 'timestamp', new Date()/1000
	Db.shared.set 'game', 'eventlist', maxId, 'type', "capture"
	Db.shared.set 'game', 'eventlist', maxId, 'beacon', beacon.n
	Db.shared.set 'game', 'eventlist', maxId, 'conqueror', nextOwner

	# Handle push notifications
	# TODO: Personalize for team members or dubed players
	Event.create
		unit: 'capture'
		text: "Team " + Db.shared.get('colors', nextOwner , 'name') + " captured a beacon"

	# Handle points and statistics
	client = args.players.split(', ')[0]
	log "[onCapture()] " + client
	beaconValue = beacon.get('captureValue')
	modifyScore client, beaconValue
	for player in args.players.split(', ')
		Db.shared.modify 'game', 'teams', getTeamOfUser(player), 'users', player, 'captured', (v) -> v+1
	Db.shared.modify 'game', 'teams', nextOwner, 'captured', (v) -> v+1
    # Modify beacon value
	beacon.modify 'captureValue', (v) -> v - 1 if beaconValue > 1

# Called by the beacon neutralize timer
exports.onNeutralize = (args) !->
	log 'args=', args
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	neutralizer = beacon.get('nextOwner')
	log 'Team ', neutralizer, ' has neutralized beacon ', beacon.n, ', players: ', args.players
	beacon.set 'percentage', 0
	beacon.set 'owner', -1

	# Handle points and statistics
	for player in args.players.split(', ')
		Db.shared.modify 'game', 'teams', getTeamOfUser(player), 'users', player, 'neutralized', (v) -> v+1
	Db.shared.modify 'game', 'teams', neutralizer, 'neutralized', (v) -> v+1

	# Handle capturing
	updateBeaconPercentage(beacon)
	percentage = beacon.get 'percentage'
	log 'Team ', neutralizer, ' is capturing beacon ', beacon.n, ' (after neutralize)'

	beacon.set 'action', 'capture'
	beacon.set 'actionStarted', new Date()/1000
	# Set timer for capturing
	Timer.set (100-percentage)*10*30, 'onCapture', args

#Function called when the game ends
exports.endGame = !->
	log "The game ended!"

# ========== Functions ==========
# Get a string of the players that are inRange of a beacon
getInrangePlayers = (beacon) ->
	playersStr = undefined
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if playersStr?
			playersStr = playersStr + ', ' + player.n
		else
			playersStr = player.n
	log 'players string: ', playersStr
	return playersStr

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

#game timer
setTimer = !->
	if Db.shared.get('game', 'roundTimeUnit') is 'Months'
		seconds = Db.shared.get('game', 'roundTimeNumber')*2592000
	else if Db.shared.get('game', 'roundTimeUnit') is 'Days'
		seconds = Db.shared.get('game', 'roundTimeNumber')*86400
	else if Db.shared.get('game', 'roundTimeUnit') is 'Hours'
		seconds = Db.shared.get('game', 'roundTimeNumber')*3600
	end = Plugin.time()+seconds #in seconds
	Db.shared.set 'game', 'endTime', end
	Timer.cancel
	Timer.set seconds*1000, #'endGame' endGame is the function called when the timer ends
		
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

# Modify user and team scores by adding "points" to the current value
modifyScore = (client, points) !->
	log "[modifyScore()] client: " + client + " team: " + getTeamOfUser(client) + " points: " + points
	# calculate old number one
	teamMax = -1
	# modify user and team scores
	Db.shared.modify 'game', 'teams', getTeamOfUser(client), 'users', client, 'userScore', (v) -> v + points
	Db.shared.modify 'game', 'teams', getTeamOfUser(client), 'teamScore', (v) -> v + points

	# calculate new number one
	teamMaxNew = -1

	log "First team old: " + teamMax + " new: " + teamMaxNew

	# create score event
	# To Do: personalize for team members or dubed players
	if teamMax isnt teamMaxNew
		maxId = Db.shared.ref('game', 'eventlist').incr 'maxId'
		Db.shared.set 'game', 'eventlist', maxId, 'timestamp', new Date()/1000
		Db.shared.set 'game', 'eventlist', maxId, 'type', "score"
		Db.shared.set 'game', 'eventlist', maxId, 'leading', team.n

		Event.create
			unit: 'score'
			text: "Team " + Db.shared.get('colors', teamMaxNew.get('name')) + " took the lead!"


