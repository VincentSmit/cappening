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
Num = require 'num'

window.redraw = Obs.create(0)

# ========== Events ==========
exports.render = ->
	log 'FULL RENDER'
	#loadMap()
	# Ask for location
	if !Geoloc.isSubscribed()
		Geoloc.subscribe()
		# gamestate check
	Obs.observe ->
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
	loadOpenStreetMap()

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
	renderMap()
	renderFlags()
	Obs.observe ->
		if mapReady() and map?
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			map.setMaxBounds(L.latLngBounds(loc1, loc2))
			map._layersMinZoom = map.getBoundsZoom(L.latLngBounds(loc1, loc2))
		Obs.onClean ->
			if map?
				map.setMaxBounds()
				map._layersMinZoom = 0
	addBar()

# Help page 
helpContent = ->
    Dom.h2 "King of the Hill instructions!"
    Dom.br()
    Dom.text "There are " + Plugin.users.count().get() + " users playing"
    Dom.br()
    Dom.text "You need to venture to the real location of a beacon to conquer it"
    
scoresContent = ->
	Dom.text "The scores of all team / players"
    
logContent = ->
	Dom.text "The log file of all events"
	
setupContent = ->
	if Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId() or 'true' # TODO remove
		currentPage = Db.local.get('currentSetupPage')
		currentPage = 'setup0' if not currentPage?
		log 'currentPage=', currentPage
		if currentPage is 'setup0' # Setup team and round time
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
						Server.sync 'setupBasic', 1, 1, !-> # TODO handle form numbers correctly
							log 'Prediction of going to next setupPhase'
						Db.local.set('currentSetupPage', 'setup1')
			Dom.div !->
				Dom.style margin: "52px"
			Dom.h2 tr("Round time")
			Dom.div !->
				Dom.style Box: "middle", padding: '12px 40px 12px 8px'
				Dom.div !->
					Dom.style Flex: 'true'
					Dom.text tr "Fill in the round time (hours), this determines how long a game lasts. Recommended: 1 week (168 hours)."
				Num.render
					name: 'time'
					value: (if Db.shared then Db.shared.peek('roundTime') else 1)||24*28 # 4 weeks max
			Dom.h2 tr("Number of teams")
			Dom.div !->
				Dom.style Box: "middle", padding: '12px 40px 12px 8px'
				Dom.div !->
					Dom.style Flex: 'true'
					Dom.text tr "Fill in the number of teams."
					Dom.br()
					Dom.text tr "Recommended default: 2."
				Num.render
					name: 'teams'
					value: (if Db.shared then Db.shared.peek('numberOfTeams') else 1)||6
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
	log "renderMap started"
	# Insert map element
	Dom.div ->
		Dom.style
			position: 'absolute'
			top: '50px'
			right: '0'
			bottom: '0'
			left: '0'
			backgroundColor: '#030303'
		Dom._get().setAttribute 'id', 'OpenStreetMap'
	### javascript way to do it:
	Obs.observe ->
		#mapReady.modify () -> false
		mapelement = document.createElement "div"
		mapelement.setAttribute 'id', 'OpenStreetMap'
		mapelement.style.width = '100%'
		mapelement.style.position = 'absolute'
		mapelement.style.top = '50px'
		mapelement.style.bottom = '0'
		mapelement.style.left = '0'
		mapelement.style.right = '0'
		mapelement.style.backgroundColor = '#030303'
		#mapelement.style.visibility = 'hidden'
		#mapelement.style.opacity = '0'
		mainElement = document.getElementsByTagName("main")[0]
		mainElement.insertBefore(mapelement, mainElement.childNodes[0])
		log "  Created html element for map"
		Obs.onClean ->
			log "  Removed html element for map"
			toRemove = document.getElementById('OpenStreetMap');
			toRemove.parentNode.removeChild(toRemove);
	###
	loadOpenStreetMap()
	setupMap()
	#renderLocation();
	
loadOpenStreetMap = ->
	# Only insert these the first time
	if(not document.getElementById("mapboxJavascript")?)
		log "Started loading OpenStreetMap files"
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

# Initialize the map with tiles
setupMap = ->
	Obs.observe ->
		log "setupMap"
		if map?
			log "  map already initialized"
		else if not L?
			log "  javascript not yet loaded"
		else
			# Tile version
			L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
			window.map = L.mapbox.map('OpenStreetMap', 'nlthijs48.4153ad9d', {zoomControl:false, updateWhenIdle:false, detectRetina:true})
			layer = L.mapbox.tileLayer('nlthijs48.4153ad9d')
			log "  Initialized MapBox map"
			#mapReady.modify () -> (L? and map?)
		Obs.onClean ->
			log "onClean() of setupMap()"
			if map?
				map.remove()
				window.map = null
				log "  removed map"

# Add flags to the map
renderFlags = ->
	log "rendering flags"
	Db.shared.observeEach 'game', 'flags', (flag) !->
		if mapReady() and map?
			if not window.flagMarkers?
				log "flagMarkers list reset"
				window.flagMarkers = [];
			location = L.latLng(flag.get('location', 'lat'), flag.get('location', 'lng'))
			log "Added circle"
			renderCircle(location.lat, location.lng, {})
			log "Added flag"
			marker = L.marker(location)
			marker.bindPopup("lat: " + location.lat + "<br>long: " + location.lng)
			marker.addTo(map)
			flagMarkers.push marker
			#log 'Added marker, marker list: ', flagMarkers
		else 
			log "  map not ready yet"
		Obs.onClean ->
			if flagMarkers? and map?
				i = 0;
				while i<flagMarkers.length
					if sameLocation L.latLng(flag.get('location', 'lat'), flag.get('location', 'lng')), flagMarkers[i].getLatLng()
						map.removeLayer flagMarkers[i]
						flagMarkers.splice(flagMarkers.indexOf(flagMarkers[i]), 1)
						log 'onClean() flag'
					else
						i++
	, (flag) ->
		-flag.get()

# Listener that checks for clicking the map
addMarkerListener = (event) ->
	log 'click: ', event
	Server.send 'addMarker', event.latlng, !->
		# TODO fix predict function
		log 'test prediction add marker'
		Db.shared.set 'flags', event.latlng.lat.toString()+'_'+event.latlng.lng.toString(), {location: event.latlng}
		
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
#Commented out because causes a lot of spam needs to be fixed!
###		
renderLocation = -> 
	if Geoloc.isSubscribed()
		Obs.observe -> # Creates new observe scope, because state changes a lot this spams the console a bit
			state = Geoloc.track()
			location = state.get('latlong');
			if location?
				location = location.split(',')
				if mapReady()
					marker = L.marker(L.latLng(location[0], location[1]))
					marker.bindPopup("Hier ben ik nu!" + "<br> accuracy: " + state.get('accuracy'))
					if window.flagCurrentLocation
						map.removeLayer window.flagCurrentLocation
					marker.addTo(map)
					window.flagCurrentLocation = marker
			else
				log 'location could not be found'
###
renderCircle = (lat, long, team)-> 
	#Render the flag
	circle = L.circle([lat, long], 500, {
		color: 'red',
		fillColor: '#f03',
		fillOpacity: 0.5
	}).addTo(window.map);
	

