Db = require 'db'
Time = require 'time'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
CSS = require 'css'
Geoloc = require 'geoloc'
Form = require 'form'
Icon = require 'icon'
# Get config values, access with 'Config.<property>' (check 'config.common.coffee')
CommonConfig = require 'config'
Config = CommonConfig.getConfig()

window.redraw = Obs.create(0) # For full redraw
window.indicationArrowRedraw = Obs.create(0) # For indication arrow redraw
window.checkinLocationFunction = undefined

# ========== Events ==========
exports.render = ->
	log '8: FULL RENDER'
	if not (window.inRangeCheckinRunning?)
		window.inRangeCheckinRunning = {}
	if not (inRangeCheckinRunning[Plugin.groupId()]?)
		inRangeCheckinRunning[Plugin.groupId()] = false
	window.restoreMapLocation = true
	log 'restoreMapLocation='+restoreMapLocation
	#Server.call 'log', Plugin.userId(), "FULL RENDER"
	loadOpenStreetMap()

	Obs.observe ->
		# Check if cleanup from last game is required
		local = Db.local.peek 'gameNumber'
		remote = Db.shared.get 'gameNumber'
		log 'Game cleanup checked, local=', local, ', remote=', remote
		if !(local?) || local != remote
			log ' Cleanup performed'
			Db.local.set 'gameNumber', remote
			# Do cleanup stuff
			Db.local.remove 'currentSetupPage'
			if inRangeCheckinRunning[Plugin.groupId()]
				clearInterval(checkinLocationFunction)
				window.inRangeCheckinRunning[Plugin.groupId()] = false

	# Ask for location
	if !Geoloc.isSubscribed()
		Geoloc.subscribe()
		# gamestate check
	Obs.observe ->
		mainElement = document.getElementsByTagName("main")[0]
		mainElement.setAttribute 'id', 'main'
		redraw.get();
		gameState = Db.shared.get('gameState')
		if gameState is 0 # Setting up game by user that added plugin
			setupContent()
			Page.setTitle !->
				Dom.text 'Setup'
			if checkinLocationFunction?
				clearInterval(checkinLocationFunction)
				checkinLocationFunction = undefined
				window.inRangeCheckinRunning[Plugin.groupId()] = false
		else if gameState is 1 # Game is running
			# Set page title
			page = Page.state.get(0)
			page = "main" if (not page? or page == '')
			# Display the correct page
			if page == 'main'
				mainContent()
				Obs.observe ->
					nEnd = Db.shared.get('game', 'newEndTime')
					end = Db.shared.get('game', 'endTime')
					if nEnd? and nEnd isnt 0
						end = nEnd		
					# Make the subtitle black if the game is within 1 hour of ending
					#log 'title end='+end+', nEdn='+nEnd
					Page.setTitle !->
						if (end - Plugin.time()) < 3600
							Dom.text "Game ends "
							Time.deltaText end
							Dom.text "!"
						else
							Dom.text "Game ends "
							Time.deltaText end
			else if page == 'scores'
				scoresContent()
				Page.setTitle !->
					Dom.text 'Ranking'
			else if page == 'log'
				logContent()
				Page.setTitle !->
					Dom.text 'Game events'
		else if gameState is 2 # Game ended
			page = Page.state.get(0)
			page = "main" if (not page? or page == '')
			if page == 'main'
				endGameContent()
				Page.setTitle !->
					Dom.div !->
						if Db.shared.peek( 'game', 'firstTeam') is getTeamOfUser(Plugin.userId())
							Dom.text "Your team won!"
						else
							Dom.text "Your team lost!"
			else if page == 'scores'
				scoresContent()
				Page.setTitle !->
					Dom.text 'Ranking'
			else if page == 'log'
				logContent()
				Page.setTitle !->
					Dom.text 'Game events'				
			if checkinLocationFunction?
				clearInterval(checkinLocationFunction)
				checkinLocationFunction = undefined		
				window.inRangeCheckinRunning[Plugin.groupId()] = false			
	Obs.observe ->
		deviceId = Db.local.peek 'deviceId'
		if not deviceId?
			result = Obs.create(null)
			Server.send 'getNewDeviceId', Plugin.userId(), result.func()
			Obs.observe ->
				if result.get()?
					log 'Got deviceId ' + result.get()
					Db.local.set 'deviceId', result.get()
				else
					log 'Did not get deviceId from server'

# Render info page (gear/info icon in top bar)
exports.renderInfo = !->
	Dom.text "On the main map there are several beacons. You need to venture to the real location of a beacon to conquer it. "
	Dom.text "When you get in range of the beacon, you'll automatically start to conquer it. "
	Dom.text "When the bar at the top of your screen has been filled with your team color, you've conquered the beacon. "
	Dom.text "A neutral beacon will take 30 seconds to conquer, but an occupied beacon will take one minute. You first need to drain the opponents' color, before you can fill it with yours! "
	Dom.br()
	Dom.br()
	Dom.h2 "Rewards and winning"
	Dom.text "You gain "+Config.beaconValueInitial+" "
	if Config.beaconValueInitial==1 then Dom.text "point" else Dom.text "points"
	Dom.text " for being the first team to conquer a certain beacon. "
	Dom.text "Beacons that are in possession of your team, will have a circle around it in your team color. "
	Dom.text "Every hour the beacon is in your posession, it will generate "+Config.beaconHoldScore+" "
	if Config.beaconHoldScore==1 then Dom.text "point" else Dom.text "points"
	Dom.text ". "
	Dom.text "Unfortunately for you, your beacons can be conquered by other teams. " 
	Dom.text "Every time a beacon is conquered the value of the beacon will drop. Scores for conquering a beacon will decrease with "+Config.beaconValueDecrease+" until a minimum of "+Config.beaconValueMinimum+". "
	Dom.text "The team with the highest score at the end of the game wins. "
	Dom.text "If a team captures all beacons, the game will end quickly if the other teams stay inactive. "
	Dom.h2 "Bugs and help"
	Dom.text "Did you find a bug in the plugin? Do you have a question about the plugin that you cannot find the answer for? Contact 'thijs17' and we will try to answer you. If you are familiar with GitHub then you can also report the bug on our GitHub repository: "
	Dom.a "https://github.com/VincentSmit/cappening/issues" # TODO: check how to get this link clickable
	Dom.text "."
							
# Method that is called when admin changes settings (only restart game for now)
exports.renderSettings = !->
	if Db.shared
		Form.check
			name: 'restart'
			text: tr 'Restart'
			sub: tr 'Check this to destroy the current game and start a new one.'


# ========== Content fuctions ==========
addBar = ->
	Dom.div !->
		Dom.style
			height: "50px"
			width: '100%'
			top: '0'
			left: '0'
			position: 'absolute'
			boxShadow: "0 3px 10px 0 rgba(0, 0, 0, 1)"
			backgroundColor: hexToRGBA(Db.shared.peek('colors', getTeamOfUser(Plugin.userId()), 'hex'), 0.9)
			_textShadow: '0 0 5px #000000, 0 0 5px #000000' 
        # Removed help button moved to top of page, should be rewritten to history tab
		### 
		Dom.div !->
			Icon.render data: 'info', color: '#fff', size: 30, style: {verticalAlign: 'middle'}
			Dom.div !->
				Dom.text 'Help'
				Dom.style verticalAlign: 'middle', display: 'inline-block', marginLeft: '5px', fontSize: '13px'
			Dom.cls 'bar-button'                
			Dom.onTap !->
				Page.nav 'help' 
		###
        # Button to event log
		Dom.div !->
			Icon.render data: 'clipboard', color: '#fff', size: 30, style: {verticalAlign: 'middle'}
			Dom.div !->
				Dom.text 'Events'
				Dom.style verticalAlign: 'middle', display: 'inline-block', marginLeft: '5px', fontSize: '13px'

			Dom.cls 'bar-button'
			Dom.onTap !->   
				Page.nav 'log'
		# Button to scores page
		Dom.div !->
			Dom.div !->
				Dom.style 
					width: '29px'
					height: '30px'
					verticalAlign: 'middle'
					display: 'inline-block'
					background: "url(#{Plugin.resourceUri('ranking.png')})"
					backgroundRepeat: "no-repeat"
					backgroundPosition: "0 0"
					backgroundSize: "26px 26px"
			Dom.div !->
				Dom.text 'Ranking'
				Dom.style verticalAlign: 'middle', display: 'inline-block', marginLeft: '5px', fontSize: '13px'
			Dom.cls 'bar-button'
			Dom.onTap !->   
				Page.nav 'scores'

addProgressBar = ->
	Obs.observe ->
		Db.shared.iterate 'game', 'beacons', (beacon) !->
			action = beacon.get('action') # Subscribe to changes in action, only thing that matters
			inRangeValue = beacon.peek('inRange', Plugin.userId(), 'device')
			if inRangeValue? and (inRangeValue == 'true' || inRangeValue == Db.local.get('deviceId'))
				log 'Rendering progress bar'
				Obs.onClean ->
					log 'Cleaned progress bar...'
				dbPercentage = beacon.peek("percentage")
				nextPercentage = -1
				ownTeam = getTeamOfUser(Plugin.userId())
				nextColor = ""
				owner = beacon.peek('owner')
				nextOwner = beacon.peek('nextOwner')
				actionStarted = beacon.peek("actionStarted")
				barText = ""
				if action == "capture"
					nextPercentage=100
					dbPercentage += (new Date() /1000 -actionStarted)/30 * 100
					if dbPercentage > 100
						dbPercentage = 100
					if dbPercentage < 0
						dbPercentage = 0
					nextColor = Db.shared.peek('colors', nextOwner, 'hex')
					barText = "Capturing..."
				else if action == "recapture"
					nextPercentage=100
					dbPercentage += (new Date() /1000 -actionStarted)/30 * 100
					if dbPercentage > 100
						dbPercentage = 100
					if dbPercentage < 0
						dbPercentage = 0
					nextColor = Db.shared.peek('colors', owner, 'hex')
					if parseInt(ownTeam) is parseInt(owner)
						barText = "Recapturing..."
					else
						barText = "Enemy is recapturing..."
				else if action == "neutralize"
					nextPercentage=0
					dbPercentage -= (new Date() /1000 -actionStarted)/30 * 100
					if dbPercentage < 0
						dbPercentage = 0
					if dbPercentage > 100
						dbPercentage = 100
					nextColor = Db.shared.peek('colors', owner, 'hex')
					barText = "Neutralizing..."
				else if action == "competing"
					if owner == -1
						nextColor = Db.shared.peek('colors', nextOwner, 'hex')
					else
						nextColor = Db.shared.peek('colors', owner, 'hex')
					fromOtherTeams = 0
					log 'fromOtherTeams='+fromOtherTeams+', nextPercentage='+nextPercentage+', dbPercentage='+dbPercentage
					nextPercentage = dbPercentage
					beacon.iterate 'inRange', (player) ->
						if getTeamOfUser(player.key()) isnt ownTeam
							fromOtherTeams++
					if dbPercentage == 100 and owner == nextOwner
						if parseInt(ownTeam) is parseInt(owner)
							if fromOtherTeams > 1
								barText = "Captured, but an enemy in range!"
							else
								barText = "Captured, but enemies in range!"
						else
							if fromOtherTeams > 1
								barText = "Enemies are blocking the neutralize!"
							else
								barText = "An enemy is blocking the neutralize!"
					else
						if parseInt(owner) isnt -1
							if parseInt(ownTeam) is parseInt(owner)
								if fromOtherTeams > 1
									barText = "Preventing neutralize by the enemies!"
								else
									barText = "Preventing neutralize by an enemy!"
							else
								if fromOtherTeams > 1
									barText = "Enemies are preventing the neutralize!"
								else
									barText = "An enemy is preventing the neutralize!"
						else
							if parseInt(ownTeam) is parseInt(nextOwner)
								if fromOtherTeams > 1
									barText = "Enemies are preventing the capture!"
								else
									barText = "An enemy is preventing the capture!"
							else
								if fromOtherTeams > 1
									barText = "Preventing capture by the enemies!"
								else
									barText = "Preventing capture by an enemy!"
				else
					nextPercentage = dbPercentage
					if owner == -1
						nextColor = Db.shared.peek('colors', nextOwner, 'hex')
					else
						nextColor = Db.shared.peek('colors', owner, 'hex')
					barText = "Captured"						
				time = 0
				if nextPercentage != dbPercentage
					time = Math.abs(dbPercentage-nextPercentage) * 300
				log "nextPercentage = ", nextPercentage, ", dbPercentage = ", dbPercentage, ", time = ", time, ", action = ", action, "actionStarted=", actionStarted
				Dom.div !->
					Dom.style
						height: "25px"
						width: "100%"
						position: 'absolute'
						left: '0'
						top: '50px'
						backgroundColor: "rgba(243,243,243,0.3)"
						border: '0'
						boxShadow: "0 3px 10px 0 rgba(0, 0, 0, 1)"
					Dom.div !->
						Dom.style
							height: "25px"
							#background: '-moz-linear-gradient(top,  rgba(0,0,0,0) 0%, rgba(0,0,0,0.3) 100%)'
							#background: '-webkit-gradient(linear, left top, left bottom, color-stop(0%,rgba(0,0,0,0)), color-stop(100%,rgba(0,0,0,0.3)))'
							#background: '-webkit-linear-gradient(top,  rgba(0,0,0,0) 0%,rgba(0,0,0,0.3) 100%)'
							#background: '-o-linear-gradient(top,  rgba(0,0,0,0) 0%,rgba(0,0,0,0.3) 100%)'
							#background: '-ms-linear-gradient(top,  rgba(0,0,0,0) 0%,rgba(0,0,0,0.3) 100%)'
							background_: 'linear-gradient(to bottom,  rgba(0,0,0,0) 0%,rgba(0,0,0,0.3) 100%)'
							filter: "progid:DXImageTransform.Microsoft.gradient( startColorstr='#00000000', endColorstr='#4d000000',GradientType=0 )"
							backgroundColor: nextColor
							zIndex: "10"
						Dom._get().style.width = dbPercentage + "%"
						log "dbPercentage after balancing = ", dbPercentage
						Dom._get().style.transition = "width " + time + "ms linear"
						window.progressElement = Dom._get()
						timer = () -> window.progressElement.style.width = nextPercentage + "%"
						window.setTimeout(timer, 100)
					Dom.div !->
						Dom.text barText
						Dom.style
							width: '100%'
							color: 'white'
							marginTop: '-22px'
							textAlign: 'center'
							fontSize: '15px'
							_textShadow: '0 0 5px #000000, 0 0 5px #000000' # Double for extra visibility

addEndGameBar = ->
	Dom.div !->
		Dom.cls 'endGameBar'
		Dom.style
			backgroundColor: hexToRGBA(Db.shared.peek('colors', Db.shared.peek('game', 'firstTeam'), 'hex'), 0.9)
		if parseInt(Db.shared.peek('game', 'firstTeam')) is parseInt(getTeamOfUser(Plugin.userId()))
			Dom.text "Your team won the game!"
		else
			Dom.text "Team " + Db.shared.peek('colors', Db.shared.peek('game', 'firstTeam'), 'name') + " won, good luck next round!"
		if Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId()
			Dom.style paddingRight: '145px'
			Dom.div !->
				Dom.cls 'restartButton'
				Dom.text "RESTART GAME"
				Dom.onTap !-> 
					Server.call 'restartGame'


# ========== Page Contents ==========
# Setup pages
setupContent = ->
	if Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId()
		currentPage = Db.local.get('currentSetupPage')
		currentPage = 'setup0' if not currentPage?
		log ' currentPage =', currentPage
		if currentPage is 'setup0' # Setup team and round time
			# Variables
			numberOfTeams = Obs.create Db.shared.peek('game', 'numberOfTeams')
			roundTimeNumber = Obs.create Db.shared.peek('game', 'roundTimeNumber')
			roundTimeUnit = Obs.create Db.shared.peek('game', 'roundTimeUnit')
			# Bar to indicate the setup progress
			Dom.div !->
				Dom.cls 'stepbar'
				# Left button
				Dom.div !->
					Dom.text tr("Prev")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-left'
					Dom.cls 'stepbar-disable'
				# Middle block
				Dom.div !->
					Dom.text tr("Basic settings")
					Dom.cls 'stepbar-middle'
				# Right button
				Dom.div !->
					Dom.text tr("Next")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-right'
					Dom.onTap !->
						Server.send 'setTeams', numberOfTeams.get()
						Server.send 'setRoundTime', roundTimeNumber.get(), roundTimeUnit.get()
						Db.local.set('currentSetupPage', 'setup1')
			Dom.div !->
				Dom.style paddingTop: '50px'
				# Not enough players warning
				if Plugin.users.count().get() <= 1
					Dom.h2 "Warning"
					Dom.text "Be sure to invite some friends if you actually want to play the game. One cannot play alone! (You can test it out though)."
				# Teams input
				Dom.h2 tr("Select the number of teams")
				Dom.div !->
					Dom.cls "team-text"
				Dom.div !->
					log 'numberOfTeams.get(): ', numberOfTeams.get()
					Dom.style margin: '0 0 20px 0', height: '50px'
					renderTeamButton = (number) ->
						Dom.div !->
							Dom.text number
							Dom.cls "team-button"
							if numberOfTeams.peek() is number
								Dom.cls "team-button-current"
							else
								Dom.onTap !->
									numberOfTeams.set number
					userCount = Math.min(Plugin.users.count().get(),6)
					for number in [2..Math.max(userCount,2)]
						renderTeamButton number
				# Duration input
				Dom.h2 tr("Round time")
				Dom.text tr "Select the round time, recommended: 7 days."
				Dom.div !->
					Dom.style margin: '10px 0 10px 0', height: '81px'
					sanitize = (value) ->
						if value < 1
							return 1
						else if value > 999
							return 999
						else
							return value
					renderArrow = (direction) !->
						Dom.div !->
							Dom.style
								width: 0
								height: 0
								margin: '0 auto'
								borderStyle: "solid"
								borderWidth: "#{if direction>0 then 0 else 20}px 20px #{if direction>0 then 20 else 0}px 20px"
								borderColor: "#{if roundTimeNumber.get()<=1 then 'transparent' else '#0077cf'} transparent #{if roundTimeNumber.get()>=999 then 'transparent' else '#0077cf'} transparent"
							if (direction>0 and roundTimeNumber.get()<999) or (direction<0 and roundTimeNumber.get()>1)
								Dom.onTap !->
									roundTimeNumber.set sanitize(roundTimeNumber.peek()+direction)
					# Number input
					Dom.div !->
						Dom.style margin: '0 10px 0 0', width: '51px', float: 'left'
						renderArrow 1
						Dom.input !->
							inputElement = Dom.get()
							Dom.prop
								size: 2
								value: roundTimeNumber.get()
							Dom.style
								fontFamily: 'monospace'
								fontSize: '30px'
								fontWeight: 'bold'
								textAlign: 'center'
								border: 'inherit'
								backgroundColor: 'inherit'
								color: 'inherit'
							Dom.on 'input change', !-> roundTimeNumber.set sanitize(inputElement.value())
							Dom.on 'click', !-> inputElement.select()
						renderArrow -1
					# Unit inputs
					Dom.div !->
						Dom.style float: 'left', paddingTop: '13px'
						renderTimeButton = (unit) ->
							Dom.div !->
								Dom.text unit
								Dom.cls "time-button"
								if roundTimeUnit.get() is unit
									Dom.cls "time-button-current"
								else
									Dom.onTap !->
										roundTimeUnit.set unit
						renderTimeButton 'Hours'
						renderTimeButton 'Days'
						renderTimeButton 'Months'
				# Gameinfo setup page:
				Dom.div !->
					Dom.h2 "Game information"
					Dom.text "For game information, click the gear or information icon on the top of the page"
		else if currentPage is 'setup1' # Setup map boundaries
			# Bar to indicate the setup progress
			Dom.div !->
				Dom.cls 'stepbar'
				# Left button
				Dom.div !->
					Dom.text tr("Prev")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-left'
					Dom.onTap !->
						Db.local.set('currentSetupPage', 'setup0')
				# Middle block
				Dom.div !->
					Dom.text tr("Select gamearea")
					Dom.cls 'stepbar-middle'
				# Right button
				Dom.div !->
					Dom.text tr("Next")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-right'
					Dom.onTap !->
						Db.local.set('currentSetupPage', 'setup2')
			renderMap()
			renderBeacons()
			Obs.observe ->
				if mapReady()
					# Setup map corners
					# Update the play area square thing
					markerDragged = ->
						if mapReady()
							Server.sync 'setBounds', window.locationOne.getLatLng(), window.locationTwo.getLatLng(), !->
								log 'predicting bounds change'
								Db.shared.set 'game', 'bounds', {one: {lat: window.locationOne.getLatLng().lat, lng: window.locationOne.getLatLng().lng}, two: {lat: window.locationTwo.getLatLng().lat, lng: window.locationTwo.getLatLng().lng}}
								log 'predicted bounds: ', {one: {lat: window.locationOne.getLatLng().lat, lng: window.locationOne.getLatLng().lng}, two: {lat: window.locationTwo.getLatLng().lat, lng: window.locationTwo.getLatLng().lng}}
							checkAllBeacons()
					# Corner 1
					lat1 = Db.shared.get('game', 'bounds', 'one', 'lat')
					lng1 =  Db.shared.get('game', 'bounds', 'one', 'lng')
					if not lat1? or not lng1
						lat1 = 52.249822176849
						lng1 = 6.8396973609924
					loc1 = L.latLng(lat1, lng1)
					window.locationOne = L.marker(loc1, {draggable: true})
					locationOne.on 'dragend', ->
						log 'marker drag 1'
						markerDragged()
					locationOne.addTo(map)
					# Corner 2
					lat2 = Db.shared.get('game', 'bounds', 'two', 'lat')
					lng2 = Db.shared.get('game', 'bounds', 'two', 'lng')
					if not lat2? or not lng2
						lat2 = 52.236578295702
						lng2 = 6.8598246574402
					loc2 = L.latLng(lat2, lng2)
					window.locationTwo = L.marker(loc2, {draggable: true})
					locationTwo.on 'dragend', ->
						log 'marker drag 2'
						markerDragged()
					locationTwo.addTo(map)
					window.boundaryRectangle = L.rectangle([loc1, loc2], {color: "#ff7800", weight: 5, clickable: false})
					boundaryRectangle.addTo(map)
				Obs.onClean ->
					log 'onClean() rectangle + corners'
					if mapReady()
						map.removeLayer locationOne if locationOne?
						map.removeLayer locationTwo if locationTwo?
						map.removeLayer boundaryRectangle if boundaryRectangle?
			# Info bar
			Dom.div !->
				Dom.cls 'infobar'
				Dom.div !->
					Dom.style
						float: 'left'
						marginRight: '10px'
						width: '30px'
						_flexGrow: '0'
						_flexShrink: '0'
					Icon.render data: 'info', color: '#fff', style: { paddingRight: '10px'}, size: 30
				Dom.div !->
					Dom.style
						_flexGrow: '1'
						_flexShrink: '1'
					Dom.text "Drag the corners of the orange rectangle to define the gamearea. Click here for more information."
				Dom.onTap !->
					Modal.show tr("Gamearea setup information"), !->
						Dom.div !->
							Dom.text "Drag the corners of the orange rectangle to define the gamearea. Choose this area wisely, this is where the map will be limited to during the game."
							Dom.br()
							Dom.br()
							Dom.text "Your own location is drawn on the map as a pushpin."
							Dom.style maxWidth: '300px', textAlign: 'left'
					, (ok)->
						ok= undefined;
					,['ok', tr("Ok")]

		else if currentPage is 'setup2' # Setup beacons
			# Bar to indicate the setup progress
			Dom.div !->
				Dom.cls 'stepbar'
				# Left button
				Dom.div !->
					Dom.text tr("Prev")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-left'
					Dom.onTap !->
						Db.local.set('currentSetupPage', 'setup1')
				# Middle block
				Dom.div !->
					Dom.text tr("Place beacons")
					Dom.cls 'stepbar-middle'
				# Right button
				Dom.div !->
					Dom.text tr("Start")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-right'
					log 'setup2 new'
					if Db.shared.count('game', 'beacons').get() >=1
						Dom.onTap !->
							Server.send 'startGame'
					else
						Dom.cls 'stepbar-disable'
			renderMap()
			renderBeacons()
			Obs.observe ->
				if mapReady()
					loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
					loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
					if loc1? and loc2
						log loc1 + " " + loc2
						window.boundaryRectangle = L.rectangle([loc1, loc2], {color: "#ff7800", weight: 5, fillOpacity: 0.05, clickable: false})
						boundaryRectangle.addTo(map)
						map.on('contextmenu', addMarkerListener)
				Obs.onClean ->
					log 'onClean() rectangle'
					if mapReady()
						map.removeLayer boundaryRectangle if boundaryRectangle?
						map.off('contextmenu', addMarkerListener)
			# Info bar
			Dom.div !->
				Dom.cls 'infobar'
				Dom.div !->
					Dom.style
						float: 'left'
						marginRight: '10px'
						width: '30px'
						_flexGrow: '0'
						_flexShrink: '0'
					Icon.render data: 'info', color: '#fff', size: 30
				Dom.div !->
					Dom.style
						_flexGrow: '1'
						_flexShrink: '1'
					if Plugin.agent().android? or Plugin.agent().ios?
						Dom.text "Tap-and-hold"
					else
						Dom.text "Right-click"
					Dom.text " to place beacon on the map, "
					if Plugin.agent().android? or Plugin.agent().ios?
						Dom.text "tap-and-hold"
					else
						Dom.text "right-click"
					Dom.text " a beacon to delete it. Click here for more information."
				Dom.onTap !->
					Modal.show tr("Beacon setup information"), !->
						Dom.div !->
							if Plugin.agent().android? or Plugin.agent().ios?
								Dom.text "Tap-and-hold"
							else
								Dom.text "Right-click"
							Dom.text " to place beacon on the map. The circle indicates the capture area for a beacon, players will have to walk to that area to capture the beacon. "
							if Plugin.agent().android? or Plugin.agent().ios?
								Dom.text "Tap-and-hold"
							else
								Dom.text "Right-click"
							Dom.text " a beacon to delete it. Be sure to place beacons in places you and other members of this Happening visit often."
							Dom.br()
							Dom.br()
							Dom.text "It is recommended to place at least 10 beacons, depending on how many members this Happening has."
							Dom.style maxWidth: '300px', textAlign: 'left'
					, (ok)->
						ok= undefined;
					,['ok', tr("Ok")]
	else
		renderMap()
		renderBeacons()
		Dom.div !->
			Dom.cls 'infobar'
			Dom.style top: '0', bottom: 'auto'
			Dom.div !->
				Dom.style
					float: 'left'
					marginRight: '10px'
					width: '30px'
					_flexGrow: '0'
					_flexShrink: '0'
				Icon.render data: 'info', color: '#fff', style: { paddingRight: '10px'}, size: 30
			Dom.div !->
				Dom.style
					_flexGrow: '1'
					_flexShrink: '1'
				Dom.text "The admin/plugin owner is setting up a new game."

# Home page with map
mainContent = ->
	log "mainContent()"
	addBar()
	addProgressBar()
	renderMap()
	renderBeacons()
	#Tutorial for playing this game the first time
	userId = Plugin.userId()
	tutorial = Db.personal.peek('tutorialState', 'mainContent')
	if undefined is tutorial
		Server.send 'updateTutorialState', userId, 'mainContent'
		Modal.show tr("Are you ready to capture your first beacon?"), !->
			Dom.div tr("Walk towards the indicated area's on the map to capture a beacon.")
			Dom.div tr("You will be awarded points for capturing a beacon, and for holding it.")
			Dom.div tr("Tip: Capture all beacons with your team and win in one hour!")
		, (ok)->
			ok= undefined;
		,['ok', tr("Got it")]
	
# Scores page
scoresContent = ->
	Ui.list !->
		Dom.style
			padding: '0'
		Db.shared.iterate 'game', 'teams', (team) !->
			teamColor = Db.shared.peek('colors', team.key(), 'hex')
			teamName = Db.shared.peek('colors', team.key(), 'name')
			teamScore = Db.shared.get('game', 'teams', team.key(), 'teamScore')
			# list of teams and their scores
			expanded = Obs.create(false)
			Ui.item !->				
				Dom.style
					padding: '14px'
					minHeight: '71px'
					alignItems: 'stretch'
				Dom.div !->
					Dom.style
						width: '70px'
						height: '70px'
						background: teamColor
						backgroundSize: 'cover'
						position: 'absolute'
						_textShadow: '0 0 3px rgba(0,0,0,0.8)'
					Dom.div !->
						rank = team.get('ranking')
						Dom.style
							fontSize: "40px"
							paddingTop: "12px"
							textAlign: "center"
							color: "white"
							paddingRight: if rank==1 then '10px' else '15px'
						Dom.text rank
						rankingSuffix = {1: "st", 2: "nd", 3: "rd", 4: "th", 5: "th", 6: "th"}
						Dom.div !->
							Dom.text rankingSuffix[rank]
							Dom.style
							    position: 'absolute'
							    fontSize: '17px'
							    left: if rank==1 then '38px' else '40px'
							    top: '15px'
				Dom.div !->
					Dom.style Flex: 1, fontSize: '100%', paddingLeft: '84px'
					Dom.text "Team " + teamName + " scored " + teamScore + " points"
					if parseInt(team.key()) is parseInt(getTeamOfUser(Plugin.userId()))
						Dom.style fontWeight: 'bold'
					#log 'users: ', Plugin.users, ', length: ', Plugin.users.count().peek()
					# To Do expand voor scores
					if expanded.get() || Plugin.users.count().peek() <= 10
						team.iterate 'users', (user) !->
							Dom.div !->
								if parseInt(user.key())  isnt Plugin.userId()
									Dom.style fontWeight: 'normal'
								Dom.style clear: 'both'
								Ui.avatar Plugin.userAvatar(user.key()),
									style: margin: '6px 10px 0 0', float: 'left'
									size: 40
									onTap: (!-> Plugin.userInfo(user.key()))
								Dom.div !->
									Dom.br()
									Dom.style fontSize: '75%', marginTop: '6px', marginRight: '6px', display: 'block', float: 'left', minWidth: '75px'
									Dom.text Plugin.userName(user.key()) + " has: "
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px', display: 'block', float: 'left'
									Dom.text user.get('userScore') + " points"
									Dom.br()
									Dom.text user.get('captured') + " captured"
									Dom.br()
									Dom.text user.get('neutralized') + " neutralized"
						, (user) -> (-user.get('userScore'))
					else
						Dom.div !->
							Dom.style fontSize: '75%', marginTop: '6px'
							Dom.text "Tap for details"
				if Plugin.users.count().peek() > 10
					Dom.onTap !->
						expanded.set(!expanded.get())
		, (team) -> [team.get('ranking')]

# Eventlog page
logContent = ->
	Ui.list !->
		Dom.style
			padding: '0'
		Db.shared.iterate 'game', 'eventlist', (capture) !->
			if capture.key() != "maxId"
				#log 'capture' 
				Ui.item !->
					Dom.style
						padding: '14px'
					if capture.peek('type') is "capture" and mapReady()
						beaconId = capture.peek('beacon')
						teamId = capture.peek('conqueror')
						teamColor = Db.shared.peek('colors', teamId, 'hex')
						teamName = Db.shared.peek('colors', teamId, 'name')
						log "print capture: teamId; " + teamId
						Dom.onTap !->
							Page.nav ''
							map.setView(L.latLng(Db.shared.peek('game', 'beacons' ,beaconId, 'location', 'lat'), Db.shared.peek('game', 'beacons' ,beaconId, 'location', 'lng')), 16)
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{Plugin.resourceUri('marker-plain.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							Dom.text "Team " + teamName + " captured a beacon"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.peek('timestamp')if capture.peek('type') is "capture" and mapReady()
					else if capture.peek('type') is "captureAll"
						beaconId = capture.peek('beacon')
						teamId = capture.peek('conqueror')
						teamColor = Db.shared.peek('colors', teamId, 'hex')
						teamName = Db.shared.peek('colors', teamId, 'name')
						log "print capture: teamId; " + teamId
						Dom.onTap !->
							Page.nav ''
							map.setView(L.latLng(Db.shared.peek('game', 'beacons' ,beaconId, 'location', 'lat'), Db.shared.peek('game', 'beacons' ,beaconId, 'location', 'lng')), 16)
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{Plugin.resourceUri('markers-plain.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							Dom.text "Team " + teamName + " team captured all beacons"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.peek('timestamp')
					else if capture.peek('type') is "score"
						teamId = capture.peek('leading')
						teamColor = Db.shared.peek('colors', teamId, 'hex')
						teamName = Db.shared.peek('colors', teamId, 'name')
						#log "print score: teamId; " + teamId
						Dom.onTap !->
							Page.nav 'scores'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{Plugin.resourceUri('rank-switch.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							Dom.text "Team " + teamName + " took the lead"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.peek('timestamp')
					else if capture.peek('type') is "cancel"
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: "#DDDDDD url(#{Plugin.resourceUri('markers-cancel-plain.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '16px'
							Dom.text "No longer are all beacons owned by one team"
							started = Db.shared.peek 'game', 'startTime'
							if started?
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px'
									Dom.text 'Happened '
									Time.deltaText started
					else if capture.peek('type') is "start"
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '55px'
								marginRight: '10px'
								background: '#DDDDDD'
								backgroundSize: 'cover'
								paddingTop: '15px'
							Dom.div !->
								Dom.style
									margin: '0 0 0 20px'
									borderLeft: '34px solid #FFFFFF'
									borderTop: '20px solid transparent'
									borderBottom: '20px solid transparent'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '16px'
							Dom.text "Start of the game!"
							started = Db.shared.peek 'game', 'startTime'
							if started?
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px'
									Dom.text 'Started '
									Time.deltaText started
					else if capture.peek('type') is "end"
						teamId = Db.shared.peek('game', 'firstTeam')
						teamColor = Db.shared.peek('colors', teamId, 'hex')
						teamName = Db.shared.peek('colors', teamId, 'name')
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor + " url(#{Plugin.resourceUri('ranking-plain.png')}) no-repeat 10px 10px"
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '16px'
							Dom.text "Team " + teamName + " won the game"
							started = Db.shared.peek 'game', 'startTime'
							if started?
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px'
									Dom.text 'Started '
									Time.deltaText started
		, (capture) -> (-capture.key())

# End game page
endGameContent = ->
	log "endGameContent()"
	addBar()
	renderMap()
	renderBeacons()
	#mModal.show("Team " + Db.shared.peek('colors', Db.shared.peek('game', 'winningTeam'), 'name') + " won the game!")
	addEndGameBar()


# ========== Map functions ==========
# Render a map
renderMap = ->
	log " renderMap()"
	# Insert map element
	Obs.observe ->
		if mapElement?
			# use it again
			mainElement = document.getElementsByTagName("main")[0]
			mainElement.insertBefore(mapElement, mainElement.childNodes[0])  # Inserts the element at the start
			if mapReady()
				map.invalidateSize(true)
			log "Reused html element for map"
		else
			window.mapElement = document.createElement "div"
			mapElement.setAttribute 'id', 'OpenStreetMap'
			mainElement = document.getElementsByTagName("main")[0]
			mainElement.insertBefore(mapElement, mainElement.childNodes[0])  # Inserts the element at the start
			if mapReady()
				map.invalidateSize(true)
			log "Created html element for map"
		Obs.onClean ->
			log "Removed html element for map (stored for later)"
			toRemove = document.getElementById('OpenStreetMap');
			toRemove.parentNode.removeChild(toRemove);
	setupMap()
	renderLocation();

loadOpenStreetMap = ->
	log "loadOpenStreetMap()"
	# Only insert these the first time
	if(not document.getElementById("mapboxJavascript")?)
		log "Started loading OpenStreetMap files"
		# Insert CSS
		css = document.createElement "link"
		css.setAttribute "rel", "stylesheet"
		css.setAttribute "type", "text/css"
		css.setAttribute "id", "mapboxCSS"
		css.setAttribute "href", "https://api.tiles.mapbox.com/mapbox.js/v2.1.9/mapbox.css"
		document.getElementsByTagName("head")[0].appendChild css
		
		# Insert javascript
		javascript = document.createElement 'script'
		javascript.setAttribute 'type', 'text/javascript'
		javascript.setAttribute 'id', 'mapboxJavascript'
		if javascript.readyState  # Internet Explorer
			javascript.onreadystatechange = ->
				if javascript.readyState == "loaded" || javascript.readyState == "complete"
					log "OpenStreetMap files loaded"
					javascript.onreadystatechange = 'null'
					redraw.incr()
		else  # Other browsers
			javascript.onload = ->
				log "OpenStreetMap files loaded"
				redraw.incr()
		javascript.setAttribute 'src', 'https://api.tiles.mapbox.com/mapbox.js/v2.1.9/mapbox.js'
		document.getElementsByTagName('head')[0].appendChild javascript
	else 
		log "OpenStreetMap files already loaded"

# Initialize the map with tiles
setupMap = ->
	Obs.observe ->
		log "setupMap()"
		saveMapLocation = () ->
			Db.local.set('mapLocation', 'lat', map.getCenter().lat)
			Db.local.set('mapLocation', 'lng', map.getCenter().lng)
			Db.local.set('mapLocation', 'zoom', map.getZoom())
		if map?
			log "map already initialized"
			limitToBounds()
			map.on('moveend', saveMapLocation)
			restoreMapLocationNow()
		else if not L?
			log "javascript not yet loaded"
		else
			# Tile version
			L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
			window.map = L.mapbox.map('OpenStreetMap', 'nlthijs48.4153ad9d', {center: [52.249822176849, 6.8396973609924], zoom: 13, zoomControl:false, updateWhenIdle:false, detectRetina:true, reuseTiles: true})
			layer = L.mapbox.tileLayer('nlthijs48.4153ad9d', {reuseTiles: true})
			log "Initialized MapBox map"
			limitToBounds()
			map.on('moveend', saveMapLocation)
			restoreMapLocationNow()
		Obs.onClean ->
			if mapReady()
				map.off('moveend', saveMapLocation)

# Setup map bounds
limitToBounds = ->
	Obs.observe ->
		log "Map bounds and minzoom set"
		if mapReady() and Db.shared.get('gameState') is 1
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			bounds = L.latLngBounds(loc1, loc2)
			if bounds? and loc1? and loc2?
				map._layersMinZoom = map.getBoundsZoom(bounds.pad(0.05))
				map.setMaxBounds(bounds.pad(0.05))
				limit = () -> 
					map._layersMinZoom = map.getBoundsZoom(bounds.pad(0.05))
					map.setMaxBounds(bounds.pad(0.05))
				window.setTimeout(limit, 100)
				#map.fitBounds(bounds); # Causes problems, because it zooms to max all the time
			else
				log "Bounds not existing"
			Obs.onClean ->
				if map?
					log "  Map bounds and minzoom reset"
					map.setMaxBounds()
					map._layersMinZoom = 0

# Zoom to fit map bounds
zoomToBounds = ->
	Obs.observe ->
		log "Zoomed to bounds"
		if mapReady()
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			bounds = L.latLngBounds(loc1, loc2)
			if loc1? and loc2? and bounds?
				map.fitBounds(bounds.pad(0.05));

restoreMapLocationNow = ->
	log 'restoreMapLocationNow() called, restoreMapLocation='+window.restoreMapLocation+', mapLocation='+JSON.stringify(Db.local.peek('mapLocation'))
	if mapReady() and Db.local.peek('mapLocation')? and window.restoreMapLocation? and window.restoreMapLocation
		location = convertLatLng(Db.local.peek('mapLocation'))
		zoom = Db.local.peek('mapLocation', 'zoom')
		log '  restoring: location='+location+', zoom='+zoom
		map.setView(location, zoom)
	window.restoreMapLocation = false

# Add beacons to the map
renderBeacons = ->
	log "rendering beacons"
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		beaconKey = beacon.key() # save the key for the onClean
		markerDelClick = undefined
		if mapReady() and map?
			# Add the marker to the map
			if not window.beaconMarkers?
				log "beaconMarkers list reset"
				window.beaconMarkers = {};
			teamNumber = beacon.get('owner')
			if teamNumber isnt undefined
				teamColor=  Db.shared.peek('colors', teamNumber, 'hex')
				
				areaIcon = L.icon({
					iconUrl: Plugin.resourceUri(teamColor.substring(1) + '.png'),
					iconSize:     [24, 40], 
					iconAnchor:   [12, 39], 
					popupAnchor:  [0, -40]
					shadowUrl: Plugin.resourceUri('markerShadow.png'),
					shadowSize: [41, 41],
					shadowAnchor: [12, 39]
				});
				
				location = L.latLng(beacon.get('location', 'lat'), beacon.get('location', 'lng'))
				marker = L.marker(location, {icon: areaIcon})

				circle = L.circle(location, Db.shared.get('game', 'beaconRadius'), {
					color: teamColor,
					fillColor: teamColor,
					fillOpacity: 0.3
					weight: 2
				});
				if Db.shared.peek('gameState') == 0 and Db.local.get('currentSetupPage') == 'setup2' 
					markerDelClick = (e) ->
						map.removeLayer circle
						map.removeLayer marker
						Server.send 'deleteBeacon', Plugin.userId(), e.latlng
					marker.on('dblclick', markerDelClick)
					marker.on('contextmenu', markerDelClick)					
				else if Db.shared.peek('gameState') != 0				
					popupString = ""
					if parseInt(beacon.peek('owner')) is parseInt(getTeamOfUser(Plugin.userId()))
						popupString += "Beacon owned by your team."
						if Config.beaconHoldScore == 1
							popupString += "<br>Scoring "+Config.beaconHoldScore+" point per hour while held."
						else
							popupString += "<br>Scoring "+Config.beaconHoldScore+" points per hour while held."
					else
						popupString += "Beacon owned by team " + Db.shared.peek('colors', beacon.peek('owner'), 'name') + "."
					popupString += "<br>Next capture gives " + beacon.peek('captureValue') + " points."

					selfInRange = false
					beacon.iterate 'inRange', (player) !->
						if parseInt(player.key()) is parseInt(Plugin.userId())
							selfInRange = true
					if selfInRange
						inrange = getInRange(beacon)
						if inrange?
							popupString += "<br>In range players: " + inrange

					popup = L.popup()
						.setLatLng(location)
						.setContent(popupString)
					marker.bindPopup(popup,  {closeOnClick: true, closeButton: false})
					markerClick = () -> 
						beaconMarkers[beacon.key()].togglePopup()		
					marker.on('contextmenu', markerClick)
				marker.addTo(map)
				beaconMarkers[beacon.key()] = marker
				#log 'Added marker, marker list: ', beaconMarkers
				
				# Add the area circle to the map 
				if not window.beaconCircles?
					log "beaconCircles list reset"
					window.beaconCircles = {}

				# Open the popup of the marker
				if Db.shared.peek('gameState') == 0 and Db.local.get('currentSetupPage') == 'setup2'
					circleDelClick = () ->
						map.removeLayer circle
						map.removeLayer marker
						Server.send 'deleteBeacon', Plugin.userId(), circle.getLatLng()
					circle.on('dblclick', circleDelClick)
					circle.on('contextmenu', circleDelClick)
				else if Db.shared.peek('gameState') != 0
					circleClick = () -> 
						beaconMarkers[beacon.key()].togglePopup()		
					circle.on('contextmenu', circleClick)
					circle.on('click', circleClick)
				circle.addTo(map)
				beaconCircles[beaconKey] = circle
				log "Added beacon and circle"
		else 
			log "map not ready yet"
		Obs.onClean ->
			if beaconMarkers? and map? and beaconCircles?
				if markerDelClick?
					marker.off('dblclick', markerDelClick)
					marker.off('contextmenu', markerDelClick)
				log 'onClean() beacon+circle'
				if beaconMarkers[beaconKey]?
					map.removeLayer beaconMarkers[beaconKey]
					delete beaconMarkers[beaconKey]
				if beaconCircles[beaconKey]?
					map.removeLayer beaconCircles[beaconKey]
					delete beaconCircles[beaconKey]
	, (beacon) ->
		-beacon.get()	

# Listener that checks for clicking the map
addMarkerListener = (event) ->
	log 'click: ', event
	beaconRadius = Db.shared.get('game', 'beaconRadius')
	#Check if marker is not close to other marker
	tooClose= false;
	result = ''
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		location = L.latLng(beacon.peek('location', 'lat'), beacon.peek('location', 'lng'))
		#log 'location='+location+', lat='+beacon.peek('location', 'lat')+', lng='+beacon.peek('location', 'lng')+', beacon=', beacon, ', key='+beacon.key()
		if event.latlng.distanceTo(location) < beaconRadius*2 and !tooClose
			tooClose = true;
			result = 'Beacon is placed too close to other beacon'
	#Check if marker area is passing the game border
	if !tooClose
		outsideGame = !boundaryRectangle.getBounds().contains(event.latlng)
		if outsideGame
			result = 'Beacon is outside the game border'
		
	if tooClose or outsideGame
		Modal.show(result)		
	else
		Server.sync 'addMarker', Plugin.userId(), event.latlng, !->
			Obs.observe ->
				log 'Prediction add marker'
				number = Math.floor((Math.random() * 10000) + 200)
				Db.shared.set 'game', 'beacons', number, {location: {lat: event.latlng.lat, lng: event.latlng.lng}, owner: -1}
	
# Listener for updating your location indicator
indicationArrowListener = () ->
	indicationArrowRedraw.incr()

# Convert a location to a LatLng object
convertLatLng = (location) ->
	return L.latLng(location.lat, location.lng)	

# Compare 2 locations to see if they are the same
sameLocation = (location1, location2) ->
	#log "sameLocation(), location1: ", location1, ", location2: ", location2
	return location1? and location2? and location1.lat is location2.lat and location1.lng is location2.lng

# Check if the map can be used	
mapReady = ->
	return L? and map?

#Loop through all beacons see if they are still within boundaryRectangle
checkAllBeacons = ->
	if beaconCircles? and beaconMarkers? and locationOne? and locationTwo? and mapReady()
		bounds = L.latLngBounds(locationOne.getLatLng(), locationTwo.getLatLng())
		for key of beaconCircles
			if !bounds.contains(beaconCircles[key].getBounds())
				Server.sync 'deleteBeacon', Plugin.userId(), beaconCircles[key].getLatLng()
				map.removeLayer beaconCircles[key]
				delete beaconCircles[key]
				map.removeLayer beaconMarkers[key]
				delete beaconMarkers[key]

# Render the location of the user on the map (currently broken)
renderLocation = ->
	#Server.call 'log', Plugin.userId(), "[renderLocation()]"
	Obs.observe ->
		if Geoloc.isSubscribed()
			#Server.call 'log', Plugin.userId(), "Track location"
			state = Geoloc.track(100, 0)
			Obs.observe ->
				#Server.call 'log', Plugin.userId(), "Found new location"
				location = state.get('latlong');
				if location?
					log 'Rendered location on the map'
					location = location.split(',')
					if mapReady()
						# Show the player's location on the map
						latLngObj= L.latLng(location[0], location[1])
						if not (Db.local.peek('mapLocation')?)
							window.restoreMapLocation = true
							Db.local.set('mapLocation', 'lat', latLngObj.lat)
							Db.local.set('mapLocation', 'lng', latLngObj.lng)
							Db.local.set('mapLocation', 'zoom', 16)
							restoreMapLocationNow()
						if not (Db.shared.peek('game', 'bounds', 'one', 'lat')?) and window.locationOne?
							one = L.latLng(latLngObj.lat+0.01,latLngObj.lng-0.02)
							two = L.latLng(latLngObj.lat-0.01,latLngObj.lng+0.02)
							Server.sync 'setBounds', one, two, !->
								log 'predicting bounds change'
								Db.shared.set 'game', 'bounds', {one: {lat: window.locationOne.getLatLng().lat, lng: window.locationOne.getLatLng().lng}, two: {lat: window.locationTwo.getLatLng().lat, lng: window.locationTwo.getLatLng().lng}}
								log 'predicted bounds: ', {one: {lat: window.locationOne.getLatLng().lat, lng: window.locationOne.getLatLng().lng}, two: {lat: window.locationTwo.getLatLng().lat, lng: window.locationTwo.getLatLng().lng}}
							map.setView(latLngObj)
						locationIcon = L.icon({
							iconUrl: Plugin.resourceUri('location.png'),
							iconSize:     [21, 40], 
							iconAnchor:   [11, 40], 
							popupAnchor:  [0, -40]
						});
						if not (beaconCurrentLocation?)
							window.beaconCurrentLocation = L.marker(latLngObj, {icon: locationIcon})
							markerClick = () -> 
								beaconCurrentLocation.togglePopup()	
							beaconCurrentLocation.on('contextmenu', markerClick)
							beaconCurrentLocation.bindPopup("This is your current location." + "<br>Accuracy: " + accuracy, {closeOnClick: true, closeButton: false})						
							beaconCurrentLocation.addTo(map)
						beaconCurrentLocation.setLatLng(latLngObj)
						accuracy = undefined
						if state.get('accuracy') < 1000
							accuracy = Math.round(state.get('accuracy')) + 'm'
						else
							accuracy = Math.round(state.get('accuracy')/1000) + 'km'
						beaconCurrentLocation.setPopupContent("This is your current location." + "<br>Accuracy: " + accuracy)
						
						# GeoLocation information bar (testing purposes)
						###
						Dom.div !->
							Dom.cls 'infobar'
							Dom.div !->
								Dom.style
									float: 'left'
									marginRight: '10px'
									width: '30px'
									_flexGrow: '0'
									_flexShrink: '0'
								Icon.render data: 'info', color: '#fff', style: { paddingRight: '10px'}, size: 30
							Dom.div !->
								Dom.style
									_flexGrow: '1'
									_flexShrink: '1'
								Dom.text "lat=" + location[0] + ", lng=" + location[1] + ", accuracy=" + state.get('accuracy') + ", slow=" + state.get('slow') + ", time=" + state.get('timestamp') + " ("
								Time.deltaText state.get('timestamp')/1000
								Dom.text ") "
						###
						Obs.observe ->
							indicationArrowRedraw.get()
							if mapReady()
								if (Db.shared.peek('gameState') is 1 or (Db.shared.peek('gameState') is 0 and (!Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId()))) and map.getBounds()?
									map.on('moveend', indicationArrowListener)
									# Render an arrow that points to your location if you do not have it on your screen already
									if !(map.getBounds().contains(latLngObj))
										#log 'Your location is outside your viewport, rendering indication arrow'
										center= map.getBounds().getSouthWest()										
										difLat = Math.abs(latLngObj.lat - center.lat)
										difLng = Math.abs(latLngObj.lng - center.lng)
										angle = 0
										if latLngObj.lng > center.lng and latLngObj.lat > center.lat
											angle = Math.atan(difLng/difLat) 
										else if latLngObj.lng > center.lng and latLngObj.lat <= center.lat
											angle = Math.atan(difLat/difLng)+ Math.PI/2 
										else if latLngObj.lng <= center.lng and latLngObj.lat <= center.lat
											angle = Math.atan(difLng/difLat)+ Math.PI
										else if latLngObj.lng <= center.lng and latLngObj.lat > center.lat
											angle = (Math.PI-Math.atan(difLng/difLat)) + Math.PI
										angleDeg = 	angle*180/Math.PI
										#log 'angleDeg=', angleDeg
										t = "rotate(" +angle + "rad)"
										distanceToPlayfield = latLngObj.distanceTo(center)
										if distanceToPlayfield <= 1000
											distanceToPlayfield = Math.round(distanceToPlayfield) + "m"
										if distanceToPlayfield > 1000
											distanceToPlayfield = Math.round(distanceToPlayfield/1000) + "km"
										Dom.div !->
											Dom.cls 'indicationArrow'
											Dom.style
												mozTransform: t
												msTransform: t
												oTransform: t
												webkitTransform: t
												transform: t
												backgroundColor: Db.shared.peek('colors', getTeamOfUser(Plugin.userId()), 'hex')
										Dom.div !->
											Dom.cls 'arrowDivText'
											Dom.text "You're " + distanceToPlayfield + " away"											
							Obs.onClean ->
								# Deregister move/zoom listeners to update indication arrow
								if mapReady()
									map.off('moveend', indicationArrowListener)
						# Checking if users are capable of taking over beacons
						Obs.observe ->
							if Db.shared.peek('gameState') is 1 # Only when the game is running, do something
								log 'Checking beacon takeover'
								Db.shared.iterate 'game', 'beacons', (beacon) !->
									beaconCoord = L.latLng(beacon.peek('location', 'lat'), beacon.peek('location', 'lng'))
									if not beaconCoord?
										log 'beacon coordinate not found'
									else
										distance = latLngObj.distanceTo(beaconCoord)
										#log 'distance=', distance, 'beacon=', beacon
										beaconRadius = Db.shared.peek('game', 'beaconRadius')
										within = distance - beaconRadius <= 0
										deviceId = Db.local.peek('deviceId')
										inRangeValue = beacon.peek('inRange', Plugin.userId(), 'device')
										accuracy = state.get('accuracy')
										checkinLocation = ->
											if parseInt(Db.shared.peek('gameState')) is 1
												log 'checkinLocation: user='+Plugin.userName(Plugin.userId())+' ('+Plugin.userId()+'), deviceId='+deviceId+', accuracy='+accuracy
												Server.send 'checkinLocation', Plugin.userId(), latLngObj, deviceId, accuracy
											else
												clearInterval(checkinLocationFunction)
												checkinLocationFunction = undefined
												window.inRangeCheckinRunning[Plugin.groupId()] = false
										if within
											log 'accuracy='+accuracy+', beaconRadius='+beaconRadius
											if accuracy > beaconRadius # Deny capturing with low accuracy
												if not inRangeValue?
													#clearInterval(checinLocation) # TODO check if this is required or causes problems
													#inRangeCheckinRunning[Plugin.groupId()] = false
													log 'Did not checkin location, accuracy too low: '+accuracy
													Dom.div !->
														Dom.cls 'infobar'
														Dom.div !->
															Dom.style
																float: 'left'
																marginRight: '10px' 
																width: '30px'
																_flexGrow: '0'
																_flexShrink: '0'
															Icon.render data: 'warn', color: '#fff', style: {paddingRight: '10px'}, size: 30
														Dom.div !->
															Dom.style
																_flexGrow: '1'
																_flexShrink: '1'
															Dom.text 'Your accuracy of '+accuracy+' meter is higher than the maximum allowed '+beaconRadius+' meter.'
											else
												if inRangeValue?
													if not (inRangeCheckinRunning[Plugin.groupId()]?) or not (inRangeCheckinRunning[Plugin.groupId()])
														checkinLocation()
														setInterval(checkinLocation, 30*1000)
														checkinLocationFunction = checkinLocation
														window.inRangeCheckinRunning[Plugin.groupId()] = true
												else
													log 'Trying beacon takeover: userId='+Plugin.userId()+', location='+latLngObj+', deviceId='+deviceId
													checkinLocation()
													if not (inRangeCheckinRunning[Plugin.groupId()]?) or not (inRangeCheckinRunning[Plugin.groupId()])
														setInterval(checkinLocation, 30*1000)
														checkinLocationFunction = checkinLocation
														window.inRangeCheckinRunning[Plugin.groupId()] = true
										else if (not within and inRangeValue? and (inRangeValue == deviceId || inRangeValue == 'true'))
											log 'Trying stop of beacon takeover: userId='+Plugin.userId()+', location='+latLngObj+', deviceId='+deviceId
											checkinLocation()
											if inRangeCheckinRunning[Plugin.groupId()]
												clearInterval(checkinLocationFunction)
												window.inRangeCheckinRunning[Plugin.groupId()] = false
				else
					log 'Location could not be found'
		Obs.onClean ->
			#Server.call 'log', Plugin.userId(), "Untrack location"

# ========== Functions ==========
# Get the team id the user is added to
getTeamOfUser = (userId) ->
	result = -1
	Db.shared.iterate 'game', 'teams', (team) !->
		if team.peek('users', userId, 'userName')?
			result = team.key()
	#if result is -1
	#	log 'Warning: Did not find team for userId=', userId
	return result

hexToRGBA = (hex, opacity) ->
	result = 'rgba('
	hex = hex.replace '#', ''
	if hex.length is 3
		result += [parseInt(hex.slice(0,1) + hex.slice(0, 1), 16), parseInt(hex.slice(1,2) + hex.slice(1, 1), 16), parseInt(hex.slice(2,3) + hex.slice(2, 1), 16), opacity]
	else if hex.length is 6
		result += [parseInt(hex.slice(0,2), 16), parseInt(hex.slice(2,4), 16), parseInt(hex.slice(4,6), 16), opacity]
	else
		result += [0, 0, 0, 0.0]
	return result+')'

getInRange = (beacon) ->
	players = undefined;
	beacon.iterate 'inRange', (user) !->
		if players?
			players = players+', '+Plugin.userName(user.key())
		else
			players = Plugin.userName(user.key())
	return players;
