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

window.redraw = Obs.create(0)
window.indicationArrowRedraw = Obs.create(0);

# ========== Events ==========
exports.render = ->
	log Db.shared
	log 'FULL RENDER'
	loadOpenStreetMap()

	Obs.observe ->
		# Check if cleanup from last game is required
		local = Db.local.get 'gameNumber'
		remote = Db.shared.get 'gameNumber'
		log 'Game cleanup checked, local=', local, ', remote=', remote
		if !(local?) || local != remote
			log ' Cleanup performed'
			Db.local.set 'gameNumber', remote
			# Do cleanup stuff
			Db.local.remove 'currentSetupPage'

	# Ask for location
	if !Geoloc.isSubscribed()
		Geoloc.subscribe()
		# gamestate check
	Obs.observe ->
		mainElement = document.getElementsByTagName("main")[0]
		mainElement.setAttribute 'id', 'main'

		redraw.get();
		limitToBounds()
		gameState = Db.shared.get('gameState')
		if gameState is 0 # Setting up game by user that added plugin
			setupContent()
		else if gameState is 1 # Game is running
			# Set page title
			page = Page.state.get(0)
			page = "main" if not page?   
			Page.setTitle page
			# Display the correct page
			if page == 'main'
				mainContent()
			else if page == 'help'
				helpContent()
			else if page == 'scores'
				scoresContent()
			else if page == 'log'
				logContent()

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
			zIndex: "5"
			boxShadow: "0 3px 10px 0 rgba(0, 0, 0, 1)"
        #DIV button to help page
		Dom.div !->
			Dom.text  "?"
			Dom.cls 'bar-button'                
			Dom.onTap !->
				Page.nav 'help' 
        #DIV button to Event log
		Dom.div !->
			Dom.text "Event Log"
			Dom.cls 'bar-button'
			Dom.onTap !->   
				Page.nav 'log'
		#DIV button to help page
		Dom.div !->
			Dom.text "Scores"
			Dom.cls 'bar-button'
			Dom.onTap !->   
				Page.nav 'scores'
		#DIV button to main menu
		Dom.div !->
			teamId = getTeamOfUser(Plugin.userId())
			Obs.observe !->
				Dom.text Db.shared.get( 'game', 'teams', teamId, 'teamScore') + " points"
			Dom.cls 'bar-button'
			Dom.style ->
				backgroundColor: Db.shared.peek('colors', teamId, 'hex')

addProgressBar = ->
	Obs.observe ->
		log 'Render progress bar outer'
		Db.shared.iterate 'game', 'beacons', (beacon) !->
			action = beacon.get('action') # Subscribe to changes in action, only thing that matters
			log 'action=', action
			if beacon.peek('inRange', Plugin.userId())?
				log 'Rendering progress bar'
				Obs.onClean ->
					log 'Cleaned progress bar...'
				dbPercentage = beacon.peek("percentage")
				nextPercentage = -1
				nextColor = ""
				owner = beacon.peek('owner')
				nextOwner = beacon.peek('nextOwner')
				actionStarted = beacon.peek("actionStarted")
				log 'Action started ', new Date()/1000-actionStarted, ' seconds ago'
				barText = ""
				if action == "capture"
					nextPercentage=100
					dbPercentage += (new Date() /1000 -actionStarted)/30 * 100
					#dbPercentage -= 9.8
					log "actionStarted = " + actionStarted
					if dbPercentage > 100
						dbPercentage = 100
					if dbPercentage < 0
						dbPercentage = 0
					nextColor = Db.shared.peek('colors', nextOwner, 'hex')
					barText = "Capturing..."
				else if action == "neutralize"
					nextPercentage=0
					dbPercentage -= (new Date() /1000 -actionStarted)/30 * 100
					if dbPercentage < 0
						dbPercentage = 0
					if dbPercentage > 100
						dbPercentage = 100
					nextColor = Db.shared.peek('colors', owner, 'hex')
					barText = "Neutralizing..."
				else
					nextPercentage = dbPercentage
					if owner == -1
						nextColor = Db.shared.peek('colors', nextOwner, 'hex')
					else
						nextColor = Db.shared.peek('colors', owner, 'hex')
					barText = "Competing with others..."
				if dbPercentage == 100 and owner == nextOwner
					barText = "Captured"
				time = 0

				if nextPercentage != dbPercentage
					time = Math.abs(dbPercentage-nextPercentage) * 300
				log "nextPercentage = ", nextPercentage, ", dbPercentage = ", dbPercentage, ", time = ", time, ", action = ", action
				Dom.div !->
					Dom.style
						height: "25px"
						width: "100%"
						zIndex: "5"
						backgroundColor: "rgba(243,243,243,0.3)"
						border: 0
						boxShadow: "0 3px 10px 0 rgba(0, 0, 0, 1)"
						marginBottom: '-25px'
						#overflowX: 'hidden'
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
							#_borderRadius: '12.5px'
							#padding: '0 13px 0 13px'
							#marginLeft: '-13px'
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


# Home page with map
mainContent = ->
	log "mainContent()"
	addBar()
	addProgressBar()
	renderMap()
	renderBeacons()

# Help page 
helpContent = ->
	Dom.div !->
		Dom.cls 'container'
		Dom.h2 "King of the Hill instructions!"
		Dom.text "You are playing this game with " + Plugin.users.count().get() + " users that are randomly divided over " + Db.shared.get('game','numberOfTeams') + " teams"
		Dom.br()
		Dom.br()
		Dom.text "On the main map there are several beacons. You need to venture to the real location of a beacon to conquer it. "
		Dom.text "When you get in range of the beacon, you'll automatically start to conquer it. "
		Dom.text "When the bar at the bottom of your screen has been filled with your team color, you've conquered the beacon. "
		Dom.text "A neutral beacon will take 1 minute to conquer, but an occupied beacon will take two. You first need to drain the opponents' color, before you can fill it with yours! "
		Dom.br()
		Dom.br()
		Dom.h2 "Rules"
		Dom.text "You gain 100 points for being the first team to conquer a certain beacon. "
		Dom.text "Beacons that are in possession of your team, will gain a circle around it in your team color! "
		Dom.text "Unfortunately for you, your beacons can be conquered by other teams. " 
		Dom.text "Every time a beacon is conquered the value of the beacon will drop. Scores for conquering a beacon will drop from 100 to 80, 60, 40 and 20. "
		Dom.text "However, when a beacon is conquered, it is safe for 1 hour (can't be captured by another team). "
		Dom.text "The team with the highest score at the end of the game wins. "
		Dom.br()
		Dom.br()
		Dom.h2 "Use of Map & Tabs"
		Dom.text "To find locations of beacons you can navigate over the map by swiping. To obtain a more precise location you can zoom in and out by pinching. "
		Dom.br()
		Dom.text "The score tab (that you can reach from the main screen) shows all individual and team scores. The Event Log tab shows all actions that have happened during the game (E.G. conquering a beacon). "
		Dom.text "This way you can keep track of what is going on in the game and how certain teams or individuals are performing. "
		Dom.br()
		Dom.text "The last tab in the bar shows your current team score. You can tap it to quickly find out some personal details! "

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
				Dom.div !->
					Dom.style
						width: '70px'
						height: '70px'
						background: teamColor
						backgroundSize: 'cover'
						position: 'absolute'
				Dom.div !->
					Dom.style Flex: 1, fontSize: '100%', paddingLeft: '80px'
					Dom.text "Team " + teamName + " scored " + teamScore + " points"
					# To Do expand voor scores
					if expanded.get()
						team.iterate 'users', (user) !->
							Dom.div !->
								Dom.style clear: 'both'
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px', marginRight: '6px', display: 'block', float: 'left'
									Dom.text Plugin.userName(user.n) + " has: "
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
				Dom.onTap !->
					expanded.set(!expanded.get())
		, (team) -> [(-team.get('teamScore')), team.get('name')]

logContent = ->
	Ui.list !->
		Dom.style
			padding: '0'
		Db.shared.iterate 'game', 'eventlist', (capture) !->
			if capture.key() != "maxId"
				log 'capture' 
				Ui.item !->
					Dom.style
						padding: '14px'
					if capture.get('type') is "capture" and mapReady()
						beaconId = capture.get('beacon')
						teamId = capture.get('conqueror')
						teamColor = Db.shared.peek('colors', teamId, 'hex')
						teamName = Db.shared.peek('colors', teamId, 'name')
						log "print capture: teamId; " + teamId
						Dom.onTap !->
							Page.nav 'main'
							map.setView(L.latLng(Db.shared.get('game', 'beacons' ,beaconId, 'location', 'lat'), Db.shared.get('game', 'beacons' ,beaconId, 'location', 'lng'), 18))
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor
								backgroundSize: 'cover'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							Dom.text "Team " + teamName + " captured a beacon"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.get('timestamp')
					else if capture.get('type') is "score"
						teamId = capture.get('leading')
						teamColor = Db.shared.peek('colors', teamId, 'hex')
						teamName = Db.shared.peek('colors', teamId, 'name')
						log "print score: teamId; " + teamId
						Dom.onTap !->
							page.nav 'scores'							
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor
								backgroundSize: 'cover'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							Dom.text "Team " + teamName + " took the lead"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.get('timestamp')
		, (capture) -> (-capture.get('timestamp'))
		Ui.item !->
			Dom.style
				padding: '14px'
			Dom.div !->
				Dom.style
					width: '70px'
					height: '70px'
					marginRight: '10px'
					background: '#DDDDDD'
					backgroundSize: 'cover'
			Dom.div !->
				Dom.style Flex: 1, fontSize: '120%'
				Dom.text "The game has started!"

	end = Db.shared.get('game', 'endTime')
	Dom.text "The game ends "
	Time.deltaText end

	

placedBeacons= false

setupContent = ->
	if Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId() or 'true' # TODO remove (debugging purposes)
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
				Dom.style padding: '8px'
				# Not enough players warning
				if Plugin.users.count().get() <= 1
					Dom.h2 "Warning"
					Dom.text "Be sure to invite some friends if you actually want to play the game. One cannot play alone!"
					Dom.text "(You can test it out though)."
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
					Dom.style Box: "middle", margin: '10px 0 10px 0', flexGrow: '0', flexShrink: '0'
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
								borderStyle: "solid"
								borderWidth: "#{if direction>0 then 0 else 20}px 20px #{if direction>0 then 20 else 0}px 20px"
								borderColor: "#{if roundTimeNumber.get()<=1 then 'transparent' else '#0077cf'} transparent #{if roundTimeNumber.get()>=999 then 'transparent' else '#0077cf'} transparent"
							if (direction>0 and roundTimeNumber.get()<999) or (direction<0 and roundTimeNumber.get()>1)
								Dom.onTap !->
									roundTimeNumber.set sanitize(roundTimeNumber.peek()+direction)
					# Number input
					Dom.div !->
						Dom.style Box: "vertical center", margin: '0 10px 0 0'
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
						Dom.style float: 'left', clear: 'both'
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
					Dom.text tr("Select playingfield")
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
								# TODO: fix prediction, does not work yet
								#log 'predicting bounds change'
								#Db.shared.set 'game', 'bounds', {one: window.locationOne.getLatLng(), two: window.locationTwo.getLatLng()}
								#log 'predicted bounds: ', {one: window.locationOne.getLatLng(), two: window.locationTwo.getLatLng()}
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
					Dom.text "Drag the corners of the rectangle to define the game area."

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
						placedBeacons = true
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
					Dom.onTap !->
						Server.send 'startGame'
			renderMap()
			renderBeacons()
			Obs.observe ->
				if mapReady()
					loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
					loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
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
					Dom.text "Right-click or hold to place beacon on the map. The circle indicates the area of effect for this beacon."
	else
		Dom.text tr("Admin/plugin owner is setting up the game")
		# Show map and current settings


# ========== Map functions ==========
# Render a map
renderMap = ->
	log " renderMap()"
	# Insert map element
	Obs.observe ->
		if mapElement?
			# use it again
			mainElement = document.getElementsByTagName("main")[0]
			mainElement.insertBefore(mapElement, null)  # Inserts the element at the end
			log "Reused html element for map"
		else
			window.mapElement = document.createElement "div"
			mapElement.setAttribute 'id', 'OpenStreetMap'
			mainElement = document.getElementsByTagName("main")[0]
			mainElement.insertBefore(mapElement, null)  # Inserts the element at the end
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
		if map?
			log "map already initialized"
		else if not L?
			log "javascript not yet loaded"
		else
			# Tile version
			L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
			window.map = L.mapbox.map('OpenStreetMap', 'nlthijs48.4153ad9d', {center: [52.249822176849, 6.8396973609924], zoom: 13, zoomControl:false, updateWhenIdle:false, detectRetina:true})
			layer = L.mapbox.tileLayer('nlthijs48.4153ad9d', {reuseTiles: true})
			log "Initialized MapBox map"


limitToBounds = ->
	Obs.observe ->
		log "Map bounds and minzoom set"
		if mapReady() and Db.shared.get('gameState') is 1
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			bounds = L.latLngBounds(loc1, loc2)
			if bounds? and loc1? and loc2?
				map.setMaxBounds(bounds)
			else
				log "Bounds not existing"
			#map.fitBounds(bounds); # Causes problems, because it zooms to max all the time
			map._layersMinZoom = map.getBoundsZoom(bounds)
			Obs.onClean ->
				if map?
					log "  Map bounds and minzoom reset"
					map.setMaxBounds()
					map._layersMinZoom = 0
zoomToBounds = ->
	Obs.observe ->
		log "Zoomed to bounds"
		if mapReady()
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			bounds = L.latLngBounds(loc1, loc2)
			map.fitBounds(bounds);

# Add beacons to the map
renderBeacons = ->
	log "rendering beacons"
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		beaconKey = beacon.key() # save the key for the onClean
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
				if Db.shared.peek('gameState')==0
					markerDelClick = (e) ->
						map.removeLayer circle
						map.removeLayer marker
						Server.send 'deleteBeacon', Plugin.userId(), e.latlng
					marker.on('dblclick', markerDelClick)	
				else
					popup = L.popup()
						.setLatLng(location)
						.setContent("Beacon owned by team " + Db.shared.peek('colors', beacon.peek('owner'), 'name') + "." + 
							"<br><br>lat: " + location.lat + "<br>long: " + location.lng)
					marker.bindPopup(popup)
				marker.addTo(map)
				beaconMarkers[beacon.key()] = marker
				#log 'Added marker, marker list: ', beaconMarkers
				
				# Add the area circle to the map 
				if not window.beaconCircles?
					log "beaconCircles list reset"
					window.beaconCircles = {}

				# Open the popup of the marker
				if Db.shared.peek('gameState') == 0
					circleDelClick = (e) ->
						map.removeLayer circle
						map.removeLayer marker
						Server.send 'deleteBeacon', Plugin.userId(), circle.getLatLng()
					circle.on('dblclick', circleDelClick)
				else
					circleClick = () -> 
						beaconMarkers[beacon.key()].togglePopup()		
					circle.on('click', circleClick)
				circle.addTo(map)
				beaconCircles[beaconKey] = circle
				log "Added beacon and circle"
		else 
			log "map not ready yet"
		Obs.onClean ->
			if beaconMarkers? and map?
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
	beacons = Db.shared.peek('game', 'beacons')
	tooClose= false;
	result = ''
	if beacons isnt {}
		for beacon, loc of beacons
			if event.latlng.distanceTo(convertLatLng(loc.location)) < beaconRadius*2 and !tooClose
				tooClose = true;
				result = 'Beacon is placed too close to other beacon'
	#Check if marker area is passing the game border
	if !tooClose
		circle = L.circle(event.latlng, beaconRadius)
		outsideGame = !(boundaryRectangle.getBounds().contains(circle.getBounds()))
		if outsideGame
			result = 'Beacon is outside the game border'
		
	if tooClose or outsideGame
		Modal.show(result)		
	else
		Server.sync 'addMarker', Plugin.userId(), event.latlng, !->
			# TODO: fix, creates duplicates because prediction is not cleaned up correctly, onClean not called
			###
			Obs.observe ->
				log 'Prediction add marker'
				number = Math.floor((Math.random() * 10000) + 200)
				Db.shared.set 'game', 'beacons', number, {location: {lat: event.latlng.lat, lng: event.latlng.lng}, owner: -1}
				Obs.onClean ->
					log 'clean'
			###

indicationArrowListener = (event) ->
	indicationArrowRedraw.incr()

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
		i = 0;
		for key in beaconCircles
			if beaconCircles.hasOwnPropery(key) and beaconCircles[key]?
				if !bounds.contains(beaconCircles[key].getBounds())
					map.removeLayer beaconCircles[key]
					Server.sync 'deleteBeacon', Plugin.userId(), beaconCircles[key].getLatLng()
	
# Render the location of the user on the map (currently broken)
renderLocation = -> 
	if Geoloc.isSubscribed()
		#Server.send 'log', Plugin.userId(), "Track location"
		state = Geoloc.track(100, 0)
		Obs.observe ->
			#Server.send 'log', Plugin.userId(), "Found new location"
			location = state.get('latlong');
			if location?
				log 'Rendered location on the map'
				location = location.split(',')
				if mapReady()
					# Show the player's location on the map
					latLngObj= L.latLng(location[0], location[1])
					if not (Db.shared.peek('game', 'bounds', 'one', 'lat')?)
						one = L.latLng(latLngObj.lat+0.01,latLngObj.lng-0.02)
						two = L.latLng(latLngObj.lat-0.01,latLngObj.lng+0.02)
						Server.sync 'setBounds', one, two,  !->
							# TODO: fix prediction, does not work yet
							#log 'predicting bounds change'
							#Db.shared.set 'game', 'bounds', {one: window.locationOne.getLatLng(), two: window.locationTwo.getLatLng()}
							#log 'predicted bounds: ', {one: window.locationOne.getLatLng(), two: window.locationTwo.getLatLng()}
						map.setView(latLngObj)
					locationIcon = L.icon({
						iconUrl: Plugin.resourceUri('location.png'),
						iconSize:     [40, 40], 
						iconAnchor:   [20, 40], 
						popupAnchor:  [0, -40]
					});
					marker = L.marker(latLngObj, {icon: locationIcon})
					marker.bindPopup("This is your current location." + "<br>Accuracy: " + state.get('accuracy') + 'm')
					marker.addTo(map)
					window.beaconCurrentLocation = marker
					# Info bar (testing purposes)
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
							if Db.shared.peek('gameState') isnt 0 and map.getBounds()?
								map.on('moveend', indicationArrowListener)
								# Render an arrow that points to your location if you do not have it on your screen already
								if !(map.getBounds().contains(latLngObj))
									#log 'Your location is outside your viewport, rendering indication arrow'
									# The arrow has to be inside the map element to get it rendered in the proper place, therefore plain javascript is required
									arrowDiv = document.createElement "div"
									arrowDiv.setAttribute 'id', 'indicationArrow'
									mainElement = document.getElementById("OpenStreetMap")
									if mainElement?
										mainElement.insertBefore(arrowDiv, null)  # Inserts the element at the end
										center= map.getCenter()
										
										difLat = Math.abs(latLngObj.lat - map.getCenter().lat)
										difLng = Math.abs(latLngObj.lng - map.getCenter().lng)
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
										if angleDeg<=22.5 or angleDeg > 337.5
											arrowDiv.className = 'indicationArrowN'
										else if angleDeg >22.5 and angleDeg<=67.5
											arrowDiv.className = 'indicationArrowNE'
										else if angleDeg >67.5 and angleDeg<=112.5
											arrowDiv.className = 'indicationArrowE'
										else if angleDeg >112.5 and angleDeg<=157.5
											arrowDiv.className = 'indicationArrowSE'
										else if angleDeg >157.5 and angleDeg<=202.5
											arrowDiv.className = 'indicationArrowS'
										else if angleDeg >202.5 and angleDeg<=247.5
											arrowDiv.className = 'indicationArrowSW'
										else if angleDeg >247.5 and angleDeg<=292.5
											arrowDiv.className = 'indicationArrowW'
										else if angleDeg >292.5 and angleDeg<=337.5
											arrowDiv.className = 'indicationArrowNW'
										#log 'angleDeg=', angleDeg
										arrowDiv.style.transform = "rotate(" +angle + "rad)"
										arrowDiv.style.webkitTransform = "rotate(" +angle + "rad)"
										arrowDiv.style.mozTransform = "rotate(" +angle + "rad)"
										arrowDiv.style.msTransform = "rotate(" +angle + "rad)"
										arrowDiv.style.oTransform = "rotate(" +angle + "rad)"
						Obs.onClean ->
							# Deregister move/zoom listeners to update indication arrow
							if mapReady()
								map.off('moveend', indicationArrowListener)
							# Remove the indication arrow
							toRemove = document.getElementById('indicationArrow');
							if toRemove?
								toRemove.parentNode.removeChild(toRemove);
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
									within = distance - Db.shared.peek('game','beaconRadius') <= 0
									inRange = beacon.peek('inRange', Plugin.userId())?
									if (within and not inRange) or (not within and inRange)
										Server.send 'checkinLocation', Plugin.userId(), latLngObj, !->
											log 'UserID', Plugin.userId()
											log 'UserLoc', latLngObj
										if inRange
											log 'Trying beacon takeover: userId=', Plugin.userId(), ', location=', latLngObj
										else
											log 'Trying stop of beacon takeover: userId=', Plugin.userId(), ', location=', latLngObj
			else
				log 'Location could not be found'
			Obs.onClean ->
				if mapReady() and beaconCurrentLocation?
					# Remove the location marker
					map.removeLayer beaconCurrentLocation
					window.beaconCurrentLocation = null

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