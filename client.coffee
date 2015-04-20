Db = require 'db'
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
#Num = require 'num'

window.redraw = Obs.create(0)

# ========== Events ==========
exports.render = ->
	log 'FULL RENDER'
	loadOpenStreetMap()
	# Ask for location
	if !Geoloc.isSubscribed()
		Geoloc.subscribe()
		# gamestate check
	Obs.observe ->
		mainElement = document.getElementsByTagName("main")[0]
		mainElement.setAttribute 'id', 'main'

		hey = redraw.get();
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
			right: "0"
			left: "0"
			top: "0"
			height: "50px"
			position: "absolute"
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
			Dom.text "10 pnts"
			Dom.cls 'bar-button'
			Dom.style ->
				backgroundColor: "#000"

# Home page with map
mainContent = ->
	log "mainContent()"
	addBar()
	renderMap()
	renderFlags()
	Obs.observe ->
		log "  Map bounds and minzoom set"
		if mapReady()
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			bounds = L.latLngBounds(loc1, loc2)
			map.setMaxBounds(bounds)
			map.fitBounds(bounds);
			map._layersMinZoom = map.getBoundsZoom(bounds)
		Obs.onClean ->
			if map?
				log "  Map bounds and minzoom reset"
				map.setMaxBounds()
				map._layersMinZoom = 0

# Help page 
helpContent = ->
	Dom.div !->
		Dom.cls 'container'
		Dom.h2 "King of the Hill instructions!"
		Dom.text "You are playing this game with " + Plugin.users.count().get() + " users that are randomly divided over X teams"
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
	Dom.text "The scores of all players:"	
	Dom.div ->
		Db.shared.observeEach 'game', 'teams', (team) !->
			log 'team', team.n
			Dom.h1 tr("Scores of team %1", team.n)
			Db.shared.observeEach 'game', 'teams', team.n , 'users', (user) !->
				log 'user', user.n
				Dom.text tr("%1 has a score of: %2", user.n, user.get('userScore'))	
				Dom.br()


logContent = ->
	Dom.text "The log file of all events"
	
setupContent = ->
	if Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId() or 'true' # TODO remove
		currentPage = Db.local.get('currentSetupPage')
		currentPage = 'setup0' if not currentPage?
		log 'currentPage=', currentPage
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
				# Teams input
				Dom.h2 tr("Number of teams")
				Dom.div !->
					Dom.text tr("Select the number of teams:")
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
					for number in [2..6]
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
					Dom.text tr("Boundary setup")
					Dom.cls 'stepbar-middle'
				# Right button
				Dom.div !->
					Dom.text tr("Next")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-right'
					Dom.onTap !->
						Db.local.set('currentSetupPage', 'setup2')
			renderMap()
			renderFlags()
			Obs.observe ->
				if mapReady()
					# Corner 1
					loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
					window.locationOne = L.marker(loc1, {draggable: true})
					locationOne.on 'dragend', ->
						log 'marker drag 1'
						markerDragged()
					locationOne.addTo(map)
					# Corner 2
					loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
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
		else if currentPage is 'setup2' # Setup flags
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
					Dom.text tr("Flag setup")
					Dom.cls 'stepbar-middle'
				# Right button
				Dom.div !->
					Dom.text tr("Start")
					Dom.cls 'stepbar-button'
					Dom.cls 'stepbar-right'
					log '  setup2 new'
					Dom.onTap !->
						Server.send 'startGame', !->
							log 'Predict function gameStart?'
			renderMap()
			renderFlags()
			Obs.observe ->
				if mapReady()
					loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
					loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
					window.boundaryRectangle = L.rectangle([loc1, loc2], {color: "#ff7800", weight: 5, fillOpacity: 0.05, clickable: false})
					boundaryRectangle.addTo(map)
					map.on('contextmenu', addMarkerListener)
				Obs.onClean ->
					log 'onClean() rectangle'
					if mapReady()
						map.removeLayer boundaryRectangle if boundaryRectangle?
						map.off('contextmenu', addMarkerListener)
	else
		Dom.text tr("Admin/plugin owner is setting up the game")
		# Show map and current settings


# ========== Map functions ==========
# Render a map
renderMap = ->
	log "renderMap()"
	# Insert map element
	###
	Dom.div ->
		Dom.style
			position: 'absolute'
			top: '50px'
			right: '0'
			bottom: '0'
			left: '0'
			backgroundColor: '#030303'
		Dom._get().setAttribute 'id', 'OpenStreetMap'
	###
	# javascript way to do it:
	Obs.observe ->
		if mapElement?
			# use it again
			mainElement = document.getElementsByTagName("main")[0]
			mainElement.insertBefore(mapElement, null)  # Inserts the element at the end
			log "  Reused html element for map"
		else
			window.mapElement = document.createElement "div"
			mapElement.setAttribute 'id', 'OpenStreetMap'
			mainElement = document.getElementsByTagName("main")[0]
			mainElement.insertBefore(mapElement, null)  # Inserts the element at the end
			log "  Created html element for map"
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
		log "  Started loading OpenStreetMap files"
		# Insert CSS
		css = document.createElement "link"
		css.setAttribute "rel", "stylesheet"
		css.setAttribute "type", "text/css"
		css.setAttribute "id", "mapboxCSS"
		css.setAttribute "href", "https://api.tiles.mapbox.com/mapbox.js/v2.1.6/mapbox.css"
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
					redraw.modify (v) -> v+1
		else  # Other browsers
			javascript.onload = ->
				log "OpenStreetMap files loaded"
				redraw.modify (v) -> v+1
		javascript.setAttribute 'src', 'https://api.tiles.mapbox.com/mapbox.js/v2.1.6/mapbox.js'
		document.getElementsByTagName('head')[0].appendChild javascript
	else 
		log "  OpenStreetMap files already loaded"

# Initialize the map with tiles
setupMap = ->
	Obs.observe ->
		log "setupMap()"
		if map?
			log "  map already initialized"
		else if not L?
			log "  javascript not yet loaded"
		else
			# Tile version
			L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
			window.map = L.mapbox.map('OpenStreetMap', 'nlthijs48.4153ad9d', {zoomControl:false, updateWhenIdle:false, detectRetina:true})
			layer = L.mapbox.tileLayer('nlthijs48.4153ad9d', {reuseTiles: true})
			log "  Initialized MapBox map"

# Add flags to the map
renderFlags = ->
	log "rendering flags"
	Db.shared.observeEach 'game', 'flags', (flag) !->
		if mapReady() and map?
			# Add the marker to the map
			if not window.flagMarkers?
				log "flagMarkers list reset"
				window.flagMarkers = [];
			teamNumber = flag.get('owner')
			teamColor=  Db.shared.get('colors', teamNumber, 'hex')
			
			areaIcon = L.icon({
				iconUrl: Plugin.resourceUri(teamColor.substring(1) + '.png'),
				iconSize:     [24, 40], 
				iconAnchor:   [12, 39], 
				popupAnchor:  [-3, -75]
				shadowUrl: Plugin.resourceUri('markerShadow.png'),
				shadowSize: [41, 41],
				shadowAnchor: [12, 39]
			});
			
			location = L.latLng(flag.get('location', 'lat'), flag.get('location', 'lng'))
			marker = L.marker(location, {icon: areaIcon})
			marker.bindPopup("lat: " + location.lat + "<br>long: " + location.lng)
			marker.addTo(map)
			flagMarkers.push marker
			#log 'Added marker, marker list: ', flagMarkers
			
			# Add the area circle to the map 
			if not window.flagCircles?
				log "flagCircles list reset"
				window.flagCircles = [];

			
			circle = L.circle(location, Db.shared.get('game', 'beaconRadius'), {
				color: teamColor,
				fillColor: teamColor,
				fillOpacity: 0.3
				weight: 2
			});
			circle.addTo(map)
			flagCircles.push circle
			log "Added flag and circle"
		else 
			log "  map not ready yet"
		Obs.onClean ->
			if flagMarkers? and map?
				log 'onClean() flag+circle'
				i = 0;
				while i<flagMarkers.length
					if sameLocation L.latLng(flag.get('location', 'lat'), flag.get('location', 'lng')), flagMarkers[i].getLatLng()
						map.removeLayer flagMarkers[i]
						flagMarkers.splice(flagMarkers.indexOf(flagMarkers[i]), 1)
					else
						i++
				i = 0;
				while i<flagCircles.length
					if sameLocation L.latLng(flag.get('location', 'lat'), flag.get('location', 'lng')), flagCircles[i].getLatLng()
						map.removeLayer flagCircles[i]
						flagCircles.splice(flagCircles.indexOf(flagCircles[i]), 1)
					else
						i++
	, (flag) ->
		-flag.get()

# Listener that checks for clicking the map
addMarkerListener = (event) ->
	log 'click: ', event
	beaconRadius = Db.shared.get('game', 'beaconRadius')
	#Check if marker is not close to other marker
	flags = Db.shared.peek('game', 'flags')
	tooClose= false;
	if flags isnt {}
		for flag, loc of flags
			if event.latlng.distanceTo(convertLatLng(loc.location)) < beaconRadius*2 and !tooClose
				tooClose = true;
				log 'event is too close to other circle'
	#Check if marker area is passing the game border
	if !tooClose
		circle = L.circle(event.latlng, beaconRadius)
		tooClose = !(boundaryRectangle.getBounds().contains(circle.getBounds()))
		log 'event is too close to game boundary'
		
	if tooClose
		#Todo give error message flag too close to each other
	else
		Server.send 'addMarker', event.latlng, !->
			# TODO fix predict function
			log 'test prediction add marker'
			Db.shared.set 'flags', event.latlng.lat.toString()+'_'+event.latlng.lng.toString(), {location: event.latlng}

convertLatLng = (location) ->
	return L.latLng(location.lat, location.lng)
	
			
# Update the play area square thing
markerDragged = ->
	if mapReady()
		Server.send 'setBounds', window.locationOne.getLatLng(), window.locationTwo.getLatLng(), !->
			log 'Predict function setbounds?'
	
# Compare 2 locations to see if they are the same
sameLocation = (location1, location2) ->
	#log "sameLocation(), location1: ", location1, ", location2: ", location2
	return location1? and location2? and location1.lat is location2.lat and location1.lng is location2.lng
	
# Check if the map can be used	
mapReady = ->
	return L? and map?

# Render the location of the user on the map (currently broken)
renderLocation = -> 
	if Geoloc.isSubscribed()
		state = Geoloc.track()
		Obs.observe ->
			location = state.get('latlong');
			if location?
				log 'Rendered location on the map'
				location = location.split(',')
				if mapReady()
					marker = L.marker(L.latLng(location[0], location[1]))
					marker.bindPopup("Hier ben ik nu!" + "<br> accuracy: " + state.get('accuracy'))
					if window.flagCurrentLocation
						map.removeLayer window.flagCurrentLocation
					marker.addTo(map)
					window.flagCurrentLocation = marker
			else
				log 'Location could not be found'
			Obs.onClean ->
				if mapReady() and flagCurrentLocation?
					map.removeLayer flagCurrentLocation
					window.flagCurrentLocation = null

