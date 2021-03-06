Db = require 'db'
Plugin = require 'plugin'
Timer = require 'timer'
Event = require 'event'
# Get config values, access with 'Config.<property>' (check 'config.common.coffee')
CommonConfig = require 'config'
Config = CommonConfig.getConfig()
MD5 = require 'md5'
Http = require 'http'

# ==================== Events ====================
# Game install
exports.onInstall = ->
	initializeColors()
	initializeGame()
	registerPlugin()

# Game update
exports.onUpgrade = ->
	log '[onUpgrade()] at '+new Date()
	# Check version number and upgrade if required
	version = Db.shared.peek('version')
	newVersion = version
	if not version?
		version = 0
	# Version checking
	if version < 10
		newVersion = 10
		initializeColors()
		Db.shared.remove 'history'
	if version < 12
		newVersion = 12
		Db.backend.remove('collectionRegistered')

	if version <13
		newVersion = 13
		for userId in Plugin.userIds()
			Db.personal(userId).remove 'location'
			
	# Write new version to the database
	if newVersion isnt version
		log '[onUpgrade()] Upgraded from version '+version+' to '+newVersion+'.'
		Db.shared.set 'version', newVersion
	registerPlugin()

# Check response on http request and set registered to true
exports.response = (data) ->
	log 'registered to data plugin'
	Db.backend.set('collectionRegistered', 'true')

# Config changes (by admin or plugin adder)
exports.onConfig = (config) ->
	if config.restart
		restartGame()

# Get background location from player.
exports.onGeoloc = (userId, geoloc) ->
	#log '[onGeoloc()] Geoloc from ' + Plugin.userName(userId) + '('+userId+'): ', JSON.stringify(geoloc)
	recieved = new Date()/1000
	if Db.shared.peek('gameState') is 1 and (recieved - (Db.personal(userId).peek('lastNotification', 'recieved') || 0))> 60*60
		beaconRadius = Db.shared.peek('game', 'beaconRadius')
		found= false;
		#Check if user is in range of an enemy beacon, opening the app will capture the beacon
		Db.shared.iterate 'game', 'beacons', (beacon)!->
			if (parseInt(beacon.peek('owner'),10) != parseInt(getTeamOfUser(userId),10)) and !found
				if distance(geoloc.latitude, geoloc.longitude, beacon.peek('location', 'lat'), beacon.peek('location', 'lng')) < beaconRadius
					found= true;
					if beacon.key() isnt Db.personal(userId).peek('lastNotification', 'beaconNumber')
						#send notifcation
						Event.create
							unit: 'inRange'
							include: userId
							text: 'You are in range of an enemy beacon, capture it now!'
						#Last notification send, so that the user will not be spammed with notifications
						Db.personal(userId).set('lastNotification', 'recieved', recieved)
						Db.personal(userId).set('lastNotification', 'beaconNumber', beacon.key())

# Handle new users joining the happening
exports.onJoin = (userId) ->
	log '[onJoin()] userId='+userId+', users='+Plugin.userIds()
	for player in Plugin.userIds()
		isInTeam = false
		if not (getTeamOfUser(player)?)
			log '[onJoin()] Player ' + Plugin.userName(player) + ' joined the Happening'
			if parseInt(Db.shared.peek('gameState')) == 1
				# Find teams with lowest number of members
				min = 99999
				lowest = []
				teamCount = 0
				Db.shared.iterate 'game', 'teams', (team) !->
					teamCount++
					count = 0
					Db.shared.iterate 'game', 'teams', team.key(), 'users', (user) !->
						count++
					if count < min
						min = count
						lowest = []
						lowest.push team.key()
					else if count == min
						lowest.push team.key()
				# Draw a random team from those
				randomNumber = Math.floor(Math.random() * lowest.length)
				team = lowest[randomNumber]
				if teamCount == 1 # Handle case that you started a game on your own, with 2 teams (one being empty)
					team = 1
					Db.shared.set 'game', 'teams', team, {
						teamScore: 0
						captured: 0
						neutralized: 0
					}
					updateTeamRankings()
				# Add player to team
				Db.shared.set 'game', 'teams', team, 'users', player, {
					userScore: 0
					captured: 0
					neutralized: 0
					userName: Plugin.userName(player)
				}
				log '[onJoin()] Added to team ' + team

# When http with correct key is recieved database is send
exports.onHttp = (request) ->
	if request.data?
		if MD5.externmd5(request.data) is Config.onHTTPKey
			moveData()
			request.respond 200, JSON.stringify(Db.backend.peek('history'))
			log '[onHTTP()] succesfully sent database, id='+Plugin.groupCode()
			return 0
	request.respond 200, 'wrong key'
	log '[onHTTP()] failed attempt to sent database'

#==================== Client calls ====================
# Restarts game
exports.client_restartGame = restartGame =  () ->
	#Store old game data in history
	moveData()
	#Reset game database
	initializeGame()

# Add a beacon (during setup phase)
exports.client_addMarker = (client, location) ->
	if Db.shared.peek('gameState') isnt 0
		log '[addMarker()] '+Plugin.userName(client), ' (id=', client, ') tried to add a marker while game is not in setup phase!'
	else
		log '[addMarker()] Adding marker: lat=', location.lat, ', lng=', location.lng
		nextNumber = 0
		while Db.shared.peek('game', 'beacons', nextNumber)?
			nextNumber++

		Db.shared.set 'game', 'beacons', nextNumber, {location: location}
		Db.shared.set 'game', 'beacons', nextNumber, 'owner', -1
		Db.shared.set 'game', 'beacons', nextNumber, 'nextOwner', -1
		Db.shared.set 'game', 'beacons', nextNumber, 'percentage', 0
		Db.shared.set 'game', 'beacons', nextNumber, 'captureValue', Config.beaconValueInitial
		Db.shared.set 'game', 'beacons', nextNumber, 'action', "none"

# Delete a beacon (during setup phase)
exports.client_deleteBeacon = (client, location) ->
	#Finding the right beacon
	if Db.shared.peek('gameState') isnt 0
		log '[deleteBeacon()] '+Plugin.userName(client), ' (id=', client, ') tried to delete a beacon while game is not in setup phase!'
	else
		Db.shared.iterate 'game', 'beacons', (beacon) !->
			if beacon.peek('location', 'lat') == location.lat and beacon.peek('location', 'lng') == location.lng
				log '[deleteBeacon()] Deleted beacon: key='+beacon.key()+', lat=', location.lat, ', lng=', location.lng
				Db.shared.remove 'game', 'beacons', beacon.key()

# Set the round time unit and number
exports.client_setRoundTime = (roundTimeNumber, roundTimeUnit) ->
	log '[setRoundTime()] RoundTime set to: ' + roundTimeNumber + ' ' + roundTimeUnit
	Db.shared.set 'game', 'roundTimeNumber', roundTimeNumber
	Db.shared.set 'game', 'roundTimeUnit', roundTimeUnit

# Set the number of teams
exports.client_setTeams = (teams) ->
	log '[setTeams()] Teams set to: ', teams
	Db.shared.set 'game', 'numberOfTeams', teams

# Set the game boundaries
exports.client_setBounds = (one, two) ->
	Db.shared.set 'game', 'bounds', {one: one, two: two}

# Get clients ingame user ID
# exports.client_getIngameUserId = (client) ->
# 	client.reply
exports.client_getNewDeviceId = (client, result) ->
	newId = (Db.shared.peek('maxDeviceId'))+1
	log '[getDeviceId()] newId ' + newId + ' send to ' + Plugin.userName(client) + " (" + client + ")"
	Db.shared.set 'maxDeviceId', newId
	result.reply newId

# Log a message from the client on the server(used for testing purposes)
exports.client_log = (userId, message) ->
	log '[log()] Client:'+Plugin.userName(userId)+":"+userId+": "+message

# Start the game
exports.client_startGame = ->
	if Db.shared.peek('gameState') is 0
		setTimer()
		userIds = Plugin.userIds()
		Db.shared.set 'game', 'startTime', new Date()/1000
		teams = Db.shared.peek('game','numberOfTeams')
		team = 0
		while(userIds.length > 0)
			randomNumber = Math.floor(Math.random() * userIds.length)
			Db.shared.set 'game', 'teams', team, 'users', userIds[randomNumber], 'userScore', 0
			Db.shared.set 'game', 'teams', team, 'users', userIds[randomNumber], 'captured', 0
			Db.shared.set 'game', 'teams', team, 'users', userIds[randomNumber], 'neutralized', 0
			Db.shared.set 'game', 'teams', team, 'users', userIds[randomNumber], 'userName', Plugin.userName(userIds[randomNumber])
			log '[startGame()] Team', team, 'has player', Plugin.userName(userIds[randomNumber])
			userIds.splice(randomNumber,1)
			team++
			team = 0 if team >= teams
		Db.shared.iterate 'game', 'teams', (team) !->
			Db.shared.set 'game', 'teams', team.key(), 'teamScore', 0
			Db.shared.set 'game', 'teams', team.key(), 'captured', 0
			Db.shared.set 'game', 'teams', team.key(), 'neutralized', 0
		updateTeamRankings()
		addEvent {
			timestamp: new Date()/1000
			type: "start"
		}
		Db.shared.set 'gameState', 1 # Set gameState at the end, because this triggers a repaint at the client so we want all data prepared before that
		Event.create
			unit: 'startGame'
			text: "A new game of Conquest has started!"
			path: ['log']
	else
		log '[client_startGame()] Tried to start the game while not in setup!'


# Checkin location for capturing a beacon
exports.client_checkinLocation = (client, location, device, accuracy) ->
	if Db.shared.peek('gameState') isnt 1
		log '[checkinLocation()] Client ', client, ' (', Plugin.userName(client), ') tried to capture beacon while game is not running!'
	else
		#log '[checkinLocation()] client: ', client, ', location: lat=', location.lat, ', lng=', location.lng
		beaconRadius = Db.shared.peek('game', 'beaconRadius')
		Db.shared.iterate 'game', 'beacons', (beacon) ->
			current = beacon.peek('inRange', client, 'device')?
			beaconDistance = distance(location.lat, location.lng, beacon.peek('location', 'lat'), beacon.peek('location', 'lng'))
			newStatus = beaconDistance < beaconRadius
			if newStatus != current
				# Cancel timers of ongoing caputes/neutralizes (new ones will be set below if required)
				Timer.cancel 'onCapture', {beacon: beacon.key()}
				Timer.cancel 'onNeutralize', {beacon: beacon.key()}
				removed = undefined;
				owner = beacon.peek 'owner'
				if newStatus
					if not device? # Deal with old clients by denying them to be added to inRange
						log '[checkinLocation()] Denied adding to inRange, no deviceId provided: id=' + client + ', name=' + Plugin.userName(client)
						return
					if accuracy > beaconRadius
						log '[checkinLocation()] Denied adding to inRange of '+Plugin.userName(client)+' ('+client+'), accuracy too low: '+accuracy+'m'
						return
					log '[checkinLocation()] Added to inRange: id=' + client + ', name=' + Plugin.userName(client) + ', deviceId=' + device
					beacon.set 'inRange', client, 'device', device
					refreshInrangeTimer(client, device)
				else
					inRangeDevice = beacon.peek('inRange', client, 'device')
					if inRangeDevice == device
						log '[checkinLocation()] Removed from inRange: id=' + client + ', name=' + Plugin.userName(client) + ', deviceId=' + device
						# clean takeover
						beacon.remove 'inRange', client
						removed = client
						Timer.cancel 'inRangeTimeout', {beacon: beacon.key(), client: client}
					else
						log '[checkinLocation()] Denied removing from inRange, deviceId does not match: id=' + client + ', name=' + Plugin.userName(client) + ', deviceId=' + device, ', inRangeDevice=' + inRangeDevice
				#log 'removed=', removed
				updateBeaconStatus(beacon, removed)
			else
				if current
					refreshInrangeTimer(client, device)

#Update tutorial state
exports.client_updateTutorialState = (userId, content) ->
	Db.personal(userId).set 'tutorialState',content, 1

			
# Update the takeover percentage of a beacon depening on current action and the passed time
updateBeaconPercentage = (beacon) ->
	currentPercentage = beacon.peek 'percentage'
	action = beacon.peek 'action'
	actionStarted = beacon.peek 'actionStarted'
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

updateBeaconStatus = (beacon, removed) ->
	# ========== Handle changes for inRange players ==========
	# Determine members per team
	owner = beacon.peek('owner')
	teamMembers = (0 for team in [0..5])
	inRangeCount = 0
	beacon.iterate 'inRange', (player) !->
		if parseInt(player.key(), 10) != parseInt(removed, 10)
			team = getTeamOfUser(player.key())
			teamMembers[team] = teamMembers[team]+1
			inRangeCount++
	#log 'teamMembers count: ', teamMembers

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
	#log '[checkinLocation()] Competing teams=', competing
	updateBeaconPercentage(beacon)

	# Check if there should be progress
	if competing.length == 1
		# Team will capture the flag
		activeTeam = competing[0]
		percentage = beacon.peek 'percentage'
		if activeTeam != owner
			beacon.set 'nextOwner', activeTeam			
			if owner == -1
				# Capturing
				log '[checkinLocation()] Team ', activeTeam, ' is capturing beacon ', beacon.key()
				beacon.set 'actionStarted', new Date()/1000
				beacon.set 'action', 'capture'
				# Set timer for capturing
				Timer.set (100-percentage)*10*30, 'onCapture', {beacon: beacon.key()}
			else
				# Neutralizing
				log '[checkinLocation()] Team ', activeTeam, ' is neutralizing beacon ', beacon.key()
				beacon.set 'actionStarted', new Date()/1000
				beacon.set 'action', 'neutralize'
				Timer.set percentage*10*30, 'onNeutralize', {beacon: beacon.key()}
		else if parseInt(percentage) isnt 100 and parseInt(activeTeam) is parseInt(owner)
			# Re-capture (get percentage back to 100)
			log '[checkinLocation()] Team ', activeTeam, ' is recapturing beacon ', beacon.key()
			beacon.set 'nextOwner', activeTeam
			beacon.set 'actionStarted', new Date()/1000
			beacon.set 'action', 'recapture'
			# Set timer for capturing
			Timer.set (100-percentage)*10*30, 'onReCapture', {beacon: beacon.key()}
		else
			beacon.set 'actionStarted', new Date()/1000
			beacon.set 'action', 'none'
			#log '[checkinLocation()] Active team already has the beacon, ', activeTeam, '=', owner
	else
		# No progess, stand-off
		beacon.set 'actionStarted', new Date()/1000
		if competing.length > 1 and inRangeCount > 0
			beacon.set 'action', 'competing'
			log '[checkinLocation()] Capture of beacon ', beacon.key(), ' on hold, competing teams: ', competing
		else
			beacon.set 'action', 'none'
			log '[checkinLocation()] Capture of beacon ', beacon.key(), ' stopped, left the area'



#==================== Functions called by timers ====================
#Function called when the game ends
exports.endGame = (args) ->
	if Db.shared.peek('gameState') is 1
		# Cancel timers
		Db.shared.iterate 'game', 'beacons', (beacon) ->
			Timer.cancel 'onCapture', {beacon: beacon.key()}
			Timer.cancel 'onNeutralize', {beacon: beacon.key()}
			Timer.cancel 'overtimeScore', {beacon: beacon.key()}
		# Set winning team
		winningTeam = getFirstTeam()
		log "[endGame()]"
		Db.shared.set('game', 'firstTeam', winningTeam)
		# End game and activate end game screen
		Db.shared.set 'gameState', 2
		log "[endGame()] The game ended! gameState: " + Db.shared.peek('gameState') + " args: " + args + " winningTeam: " + winningTeam + " Db: " + Db.shared.peek('game', 'firstTeam')
		# Event
		addEvent {
			timestamp: new Date()/1000
			type: "end"
		}
		# Pushbericht winnaar en verliezer
		pushToTeam(winningTeam, "Congratulations! Your team won the game!")
		pushToRest(winningTeam, "You lost the game!")
	else
		log "[endGame()] called in gameState no 1"

# Called by the beacon capture timer
# args.beacon: beacon key
exports.onCapture = (args) ->
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	nextOwner = beacon.peek('nextOwner')
	inRangeOfTeam = getInrangePlayersOfTeamArray(args.beacon, nextOwner)
	inRangeOfTeamString = getInrangePlayersOfTeam(args.beacon, nextOwner)
	log '[onCapture()] Team ', nextOwner, ' has captured beacon ', beacon.key(), ', inRange players of team: '+ inRangeOfTeam
	beacon.set 'percentage', 100
	beacon.set 'owner', nextOwner
	beacon.set 'actionStarted', new Date()/1000
	beacon.set 'action', 'none'

	# Set a timer to gain teamscore overtime
	log '[onCapture()] pointsTime: '+Config.beaconPointsTime
	Timer.set Config.beaconPointsTime, 'overtimeScore', {beacon: beacon.key()}

	# The game will end in 1 hour if all the beacons are captured by one team
	capOwner = Db.shared.peek('game', 'beacons', '0', 'owner')
	log 'capOwner', capOwner
	allBeaconsCaptured = true
	Db.shared.iterate 'game', 'beacons', (beacon) ->
		if capOwner isnt beacon.peek('owner')
			#log 'capOwner2', beacon.peek('owner')
			allBeaconsCaptured = false
			#log 'capturedBeaconState', allBeaconsCaptured
	log 'allbeaconscapturedFinal', allBeaconsCaptured
	endTime = Db.shared.peek('game', 'endTime')

	log 'inRangeOfTeamString='+inRangeOfTeamString
	# Handle push notifications and modify endTime, if needed
	if allBeaconsCaptured and endTime-Plugin.time()>(Config.beaconPointsTime/1000)
		end = Plugin.time() + Config.beaconPointsTime/1000 #in seconds
		# log 'end', end
		Db.shared.set 'game', 'newEndTime', end
		Timer.cancel 'endGame', {}
		Timer.set Config.beaconPointsTime, 'endGame', {}

		# Add event log entrie(s)
		addEvent {
			timestamp: new Date()/1000
			type: "captureAll"
			beacon: beacon.key()
			conqueror: nextOwner
			members: inRangeOfTeamString
		}
		# Notifications
		pushToTeam(nextOwner, "Your team captured all beacons! Hold for one hour and you will win this game!")
		pushToRest(nextOwner, "Team " + Db.shared.peek('colors', nextOwner, 'name') + " has captured all beacons, you have 1 hour to conquer a beacon!")
	else
		# Add event log entrie(s)
		addEvent {
			timestamp: new Date()/1000
			type: "capture"
			beacon: beacon.key()
			conqueror: nextOwner
			members: inRangeOfTeamString
		}
		# Notifications
		pushToTeam(nextOwner, "Your team captured a beacon!")
		pushToRest(nextOwner, userStringToFriendly(inRangeOfTeamString) + " of team " + Db.shared.peek('colors', nextOwner , 'name') + " captured a beacon")

	# Give 1 person of the team the individual points
	modifyScore inRangeOfTeam[0], beacon.peek('captureValue')

	# Increment captures per team and per capturer
	for player in inRangeOfTeam
		Db.shared.modify 'game', 'teams', getTeamOfUser(player) , 'users', player, 'captured', (v) -> v+1
		#log player + " from team " + getTeamOfUser(player) + " captured " + Db.shared.peek('game', 'teams', getTeamOfUser(player), 'users', player, 'captured') + " beacons"
	Db.shared.modify 'game', 'teams', nextOwner, 'captured', (v) -> v+1
    # Modify beacon value
	beacon.modify 'captureValue', (v) -> 
		if (v - Config.beaconValueDecrease)>=Config.beaconValueMinimum
			return v - Config.beaconValueDecrease
		else
			return Config.beaconValueMinimum

# Called by the beacon recapture timer
# args.beacon: beacon key
exports.onReCapture = (args) ->
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	inRangeOfTeam = getInrangePlayersOfTeamArray(args.beacon, beacon.peek('owner'))
	log '[onCapture()] Team ', beacon.peek('owner'), ' has recaptured beacon ', beacon.key(), ', inRange players of team: '+ inRangeOfTeam
	beacon.set 'percentage', 100
	beacon.set 'actionStarted', new Date()/1000
	beacon.set 'action', 'none'

# Called by the beacon neutralize timer
# args.beacon: beacon that is neutralized
exports.onNeutralize = (args) ->
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	neutralizer = beacon.peek('nextOwner')
	inRangeOfTeam = getInrangePlayersOfTeamArray(args.beacon, neutralizer)
	log '[onNeutralize()] Team ', neutralizer, ' has neutralized beacon ', beacon.key(), ', players: '+inRangeOfTeam
	beacon.set 'percentage', 0
	beacon.set 'owner', -1

	#cancel gain teamscore overtime
	Timer.cancel 'overtimeScore', {beacon: beacon.key()}

	#Call the timer to reset the time in the correct endtime in the database
	end = Db.shared.peek 'game', 'endTime'
	if Db.shared.peek('game', 'newEndTime') isnt 0
		Db.shared.set 'game', 'newEndTime', 0
		Timer.cancel 'endGame', {}
		Timer.set (end-Plugin.time())*1000, 'endGame', {}
		# Cancel event
		addEvent {
			timestamp: new Date()/1000
			type: "cancel"
		}

	# Increment neutralizes per team and per capturer
	for player in inRangeOfTeam
		Db.shared.modify 'game', 'teams', getTeamOfUser(player), 'users', player, 'neutralized', (v) -> v+1
	Db.shared.modify 'game', 'teams', neutralizer, 'neutralized', (v) -> v+1

	# Handle capturing
	updateBeaconPercentage(beacon)
	percentage = beacon.peek 'percentage'
	log '[onNeutralize()] Team ', neutralizer, ' is capturing beacon ', beacon.key(), ' (after neutralize)'

	beacon.set 'action', 'capture'
	beacon.set 'actionStarted', new Date()/1000
	# Set timer for capturing
	Timer.set (100-percentage)*10*30, 'onCapture', args

# Modify teamscore for possessing a beacon for a certain amount of time
# args.beacon: beacon that is getting points
exports.overtimeScore = (args) ->
	owner = Db.shared.peek 'game', 'beacons',  args.beacon, 'owner'
	Db.shared.modify 'game', 'teams', owner, 'teamScore', (v) -> v + Config.beaconHoldScore
	checkNewLead() # check for a new leading team
	Timer.set Config.beaconPointsTime, 'overtimeScore', args # Every hour

# Called when an inRange players did not checkin quickly enough
# args.beacon: beacon id
# args.client: user id
exports.inRangeTimeout = (args) ->
	log 'User '+Plugin.userName(args.client)+'('+args.client+') removed from inRange of beacon '+args.beacon+' (timeout)'
	Db.shared.remove 'game', 'beacons', args.beacon, 'inRange', args.client
	updateBeaconStatus(Db.shared.ref('game', 'beacons', args.beacon), -999)



# ==================== Functions ====================
# Get a string of the players that are inRange of a beacon
getInrangePlayers = (beacon) ->
	playersStr = undefined;
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if playersStr?
			playersStr = playersStr + ', ' + player.key()
		else
			playersStr = player.key()
	return playersStr

# Get a string of the players that are inRange of a beacon of a specific team
getInrangePlayersOfTeam = (beacon, team) ->
	playersStr = undefined;
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if parseInt(getTeamOfUser(player.key())) == parseInt(team)
			if playersStr?
				playersStr = playersStr + ', ' + player.key()
			else
				playersStr = player.key()
	return playersStr

# Get an array of the players that are inRange of a beacon of a specific team
getInrangePlayersOfTeamArray = (beacon, team) ->
	players = [];
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if parseInt(getTeamOfUser(player.key())) == parseInt(team)
			players.push(player.key())
	return players



# Update the rankings of teams depending on their score
updateTeamRankings = ->
	teamScores = []
	Db.shared.iterate 'game', 'teams', (team) !->
		teamScores.push {team: team.key(), score: getTeamScore(team.key())}
	#log '[updateTeamRankings()] teamScores start: ', JSON.stringify(teamScores)
	teamScores.sort((a, b) -> return parseInt(b.score)-parseInt(a.score))
	#log '[updateTeamRankings()] teamScores sorted: ', JSON.stringify(teamScores)
	# Using same ranking number for multiple teams if scores are the same
	ranking = 0
	same = 0
	lastScore = -1
	for teamObject in teamScores
		if lastScore == teamObject.score
			same++
		else
			ranking+=same
			ranking++
		Db.shared.set 'game', 'teams', teamObject.team, 'ranking', ranking
		lastScore = teamObject.score

# Get the score of a team
getTeamScore = (team) ->
	result = Db.shared.peek 'game', 'teams', team, 'teamScore'
	Db.shared.iterate 'game', 'teams', team, 'users', (user) !->
		result+=user.peek('userScore')
	return result

# Setup an empty game
initializeGame = ->
	# Stop all timers from the previous game
	Timer.cancel 'endGame', {}
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		Timer.cancel 'onCapture', {beacon: beacon.key()}
		Timer.cancel 'onNeutralize', {beacon: beacon.key()}
		Timer.cancel 'overtimeScore', {beacon: beacon.key()}
		beacon.iterate 'inRange', (client) !->
			Timer.cancel 'inRangeTimeout', {beacon: beacon.key(), client: client.key()}
	# Reset database to defaults
	Db.shared.set 'game', {}
	#Db.shared.set 'game', 'bounds', {one: {lat: 52.249822176849, lng: 6.8396973609924}, two: {lat: 52.236578295702, lng: 6.8598246574402}} # TOOD remove
	Db.shared.set 'game', 'numberOfTeams', 2
	Db.shared.set 'game', 'beaconRadius', 200
	Db.shared.set 'game', 'roundTimeUnit', 'Days'
	Db.shared.set 'game', 'roundTimeNumber', 7
	Db.shared.set 'game', 'eventlist', 'maxId', 0
	Db.shared.set 'game', 'firstTeam', -1

	Db.shared.set 'gameState', 0
	Db.shared.modify 'gameNumber', (v) -> (0||v)+1

# initialize team colors
initializeColors = ->
	Db.shared.set 'colors',
		{
			'-1': {name: 'neutral', capitalizedName: 'Neutral', hex: '#999999'},
			0:    {name: 'blue',    capitalizedName: 'Blue',    hex: '#3882b6'},
			1:    {name: 'green',   capitalizedName: 'Green',   hex: '#009F22'},
			2:    {name: 'orange',  capitalizedName: 'Orange',  hex: '#FFA200'},
			3:    {name: 'red',     capitalizedName: 'Red',     hex: '#E41B1B'},
			4:    {name: 'yellow',  capitalizedName: 'Yellow',  hex: '#F2DB0D'},
			5:    {name: 'purple',  capitalizedName: 'Purple',  hex: '#E637D8'}
		}

# Game timer
setTimer = ->
	if Db.shared.peek('game', 'roundTimeUnit') is 'Months'
		seconds = Db.shared.peek('game', 'roundTimeNumber')*2592000
	else if Db.shared.peek('game', 'roundTimeUnit') is 'Days'
		seconds = Db.shared.peek('game', 'roundTimeNumber')*86400
	else if Db.shared.peek('game', 'roundTimeUnit') is 'Hours'
		seconds = Db.shared.peek('game', 'roundTimeNumber')*3600
	end = Plugin.time()+seconds #in seconds
	Db.shared.set 'game', 'endTime', end
	Db.shared.set 'game', 'newEndTime', 0
	Timer.cancel 'endGame', {}
	Timer.set seconds*1000, 'endGame', {} #endGame is the function called when the timer ends

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
	result = undefined
	Db.shared.iterate 'game', 'teams', (team) !->
		if team.peek('users', userId, 'userName')?
			result = team.key()
	#if result is -1
	#	log 'Warning: Did not find team for userId=', userId
	return result

# Returns team with the highest score
getFirstTeam = ->
	teamMax = -1
	maxScore = -1
	Db.shared.iterate 'game', 'teams', (team) !->
		if maxScore < team.peek('teamScore')
			teamMax = team.key()
			maxScore = team.peek('teamScore')
	#log "[getFirstTeam()] teamMax: " + teamMax
	return teamMax

# Modify user and team scores by adding "points" to the current value
modifyScore = (client, points) ->
	teamClient = getTeamOfUser(client)
	log "[modifyScore()] client: " + client + " team: " + teamClient + " points: " + points
	if not(teamClient?) or parseInt(teamClient) == -1
		log "WARNING: team is undefined/-1! Stopping modifyScore()"
		return
	# modify user- and team scores
	Db.shared.modify 'game', 'teams', teamClient, 'users', client, 'userScore', (v) -> v + points
	Db.shared.modify 'game', 'teams', teamClient, 'teamScore', (v) -> v + points
	# new lead check
	checkNewLead(teamClient)

refreshInrangeTimer = (client, device) ->
	#log '[refreshInRangeTimer()] Refreshing timer for '+Plugin.userName(client)+' ('+client+') on device '+device
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		beacon.iterate 'inRange', (user) !->
			if parseInt(user.key(),10) is parseInt(client,10) and parseInt(user.peek('device'),10) is parseInt(device,10)
				#log 'Resetting timeout'
				user.set 'time', new Date()/1000
				Timer.cancel 'inRangeTimeout', {beacon: beacon.key(), client: client}
				Timer.set Config.inRangeKickTime*1000, 'inRangeTimeout', {beacon: beacon.key(), client: client}

# function called everytime scores are modified to check wheter there is a new leading team or not
checkNewLead = ->
	teamMax = getFirstTeam()
	newLead = false;
	newLead = teamMax isnt Db.shared.peek('game', 'firstTeam')
	# create score event
	# To Do: personalize for team members or dubed players
	if newLead
		log "[checkNewLead()] newLead: " + newLead + " "
		addEvent {
			timestamp: new Date()/1000
			type: "score"
			leading: teamMax
		}
		Db.shared.set 'game', 'firstTeam', teamMax # store firstTeam for next new team calculation
		pushToTeam(teamMax, "Your team took the lead!")
		pushToRest(teamMax, "Team " + Db.shared.peek('colors', teamMax, 'name') + " took the lead!")
	# Update rankings
	updateTeamRankings()

# Adds event to the eventlist
addEvent = (eventArgs) ->
	maxId = Db.shared.peek('game', 'eventlist', 'maxId')
	log "[addEvent()] Event: " + eventArgs.type + " id: " + maxId
	Db.shared.set 'game', 'eventlist', maxId, eventArgs
	Db.shared.modify 'game', 'eventlist', 'maxId', (v) -> v + 1

# Sends a push notification, message, to all team members
pushToTeam = (teamId, message) ->
	#log "[pushToTeam()] teamId: " + teamId
	#log "[pushToTeam()] message: " + message
	members = []
	Db.shared.iterate 'game', 'teams', teamId, 'users', (teamMember) !->
		members.push(teamMember.key())
	#log "[pushToTeam()] include: " + members[0]
	Event.create
    	unit: 'toTeam'
    	include: members
    	text: message
    	path: ['log']

# Sends a push notification, message, to all players not in team, teamId
pushToRest = (teamId, message) ->
	members = []
	Db.shared.iterate 'game', 'teams', teamId, 'users', (teamMember) !->
		members.push(teamMember.key())
	Event.create
    	unit: 'toRest'
    	exclude: members
    	text: message
    	path: ['log']

#Move all data to history tab
moveData = ->
	if not (Db.backend.peek('history', 'groupCode')?)
		Db.backend.set 'history', 'groupCode', Plugin.groupCode()
	if not (Db.backend.peek('history', 'players')?)
		Db.backend.set 'history', 'players', Plugin.userIds().length
	current = Db.shared.peek('gameNumber')
	if current? and parseInt(Db.shared.peek('game', 'gameState')) != 0
		Db.backend.set 'history', current,'game', Db.shared.peek('game')
		Db.backend.set 'history', current, 'gameState', Db.shared.peek('gameState')

# Called when plugin is installed. This function sends request to data collection plugin.
registerPlugin = ->
	if !(Db.backend.peek('collectionRegistered')?)
		Http.post
			url: 'https://happening.im/x/2489x'
			data: Plugin.groupCode()
			name: 'response'

# Copy found in client.coffee!
userStringToFriendly = (users) ->
	if (not (users?)) or users == ''
		return undefined
	split = users.split(', ')
	if split.length == 0
		return ""
	result = Plugin.userName(parseInt(split[0]))
	i=1
	while i<(split.length-1)
		result += ', ' + Plugin.username(parseInt(split[i]))
		i++
	if split.length > 1
		result += ' and ' + Plugin.userName(parseInt(split[split.length-1]))
	return result
