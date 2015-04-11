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

window.mapReady = Obs.create(false)

exports.render = ->
	log 'FULL RENDER'
	loadMap()
	# Ask for location
	if !Geoloc.isSubscribed()
		Geoloc.subscribe()
		# gamestate check
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
	
# Load the javascript necessary for the map
loadMap = ->
	log "loadMap started"
	
	# Insert map element
	mapToCreate = not document.getElementById("map")?
	if(mapToCreate)
		mapReady.modify () -> false
		mapelement = document.createElement "div"
		mapelement.setAttribute 'id', 'map'
		mapelement.style.width = '100%'
		mapelement.style.position = 'absolute'
		mapelement.style.top = '50px'
		mapelement.style.bottom = '0'
		mapelement.style.left = '0'
		mapelement.style.right = '0'
		mapelement.style.backgroundColor = '#030303'
		mapelement.style.visibility = 'hidden'
		mapelement.style.opacity = '0'
		mainElement = document.getElementsByTagName("main")[0]
		mainElement.insertBefore(mapelement, mainElement.childNodes[0])
	###
	Dom.div ->
		Dom.style
			position: 'absolute'
			height: '100%'
			width: '100%'
			top: '0'
			left: '0'
			backgroundColor: '#030303'
		Dom._get().setAttribute 'id', 'map'
	###
	# Only insert these the first time
	if(not document.getElementById("mapboxJavascript")?)
		log "  Started loading javascript and CSS"
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
					log "MapBox script loaded"
					javascript.onreadystatechange = 'null'
					setupMap()
		else  # Other browsers
			javascript.onload = ->
				log "MapBox script loaded"
				setupMap()
		javascript.setAttribute 'src', 'https://api.tiles.mapbox.com/mapbox.js/v2.1.6/mapbox.js'
		document.getElementsByTagName('head')[0].appendChild javascript
	if mapToCreate
		setupMap()
		
# Initialize the map with tiles
setupMap = ->
	log "setupMap"
	if L? and map?
		log "Initializing MapBox map"
		# Tile version
		L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
		window.map = L.mapbox.map('map', 'nlthijs48.4153ad9d', {zoomControl:false, updateWhenIdle:false, detectRetina:true})
		layer = L.mapbox.tileLayer('nlthijs48.4153ad9d')
		mapReady.modify () -> (L? and map?)

# Add flags to the map
renderFlags = ->
	#if Geoloc.isSubscribed()
	#	Obs.observe -> # Creates new observe scope, because state changes a lot this spams the console a bit
	#		state = Geoloc.track()
	#		location = state.get('latlong');
	#		if location?
	#			location = location.split(',')
	#			marker = L.marker(L.latLng(location[0], location[1]))
	#			marker.bindPopup("Hier ben ik nu!" + "<br> accuracy: " + state.get('accuracy'))
	#			if window.flagCurrentLocation
	#				map.removeLayer window.flagCurrentLocation
	#			marker.addTo(map)
	#			window.flagCurrentLocation = marker
	#		else
	#			log 'location could not be found'
	Db.shared.observeEach 'game', 'flags', (flag) !->
		if mapReady.get()
			if not window.flagMarkers?
				window.flagMarkers = [];
			lat = flag.get('location', 'lat')
			lng = flag.get('location', 'lng')
			log 'Adding flag: ', flag, ' lat=', lat, ', lng=', lng
			location = L.latLng(lat, lng)
			marker = L.marker(location)
			marker.bindPopup("lat: " + lat + "<br>long: " + lng)
			marker.addTo(map)
			window.flagMarkers.push marker
			log 'Added marker, marker list: ', flagMarkers
		Obs.onClean ->
			log 'flag in onclean: ', flag
			for loopFlag in window.flagMarkers
				if sameLocation flag, loopFlag
					map.removeLayer flag if flag?
					flagMarkers.splice(flagMarkers.indexOf(loopFlag))
					log 'Flag removed, onClean()'
	, (flag) ->
		-flag.get()
	
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
	Obs.observe ->
		if mapReady.get()
			# Limit scrolling to the bounds and also limit the zoom level
			loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
			loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
			map.setMaxBounds(L.latLngBounds(loc1, loc2))
			map._layersMinZoom = map.getBoundsZoom(map.getBounds())
		Obs.onClean ->
			map.setMaxBounds()
			map._layersMinZoom = 0
	showMap()
	renderFlags()
	loadMap()
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
		setupPhase = Db.shared.get('setupPhase')
		currentPage = Db.local.get('currentSetupPage')
		log 'currentPage=', currentPage
		if not currentPage?
			currentPage = 'setup' + setupPhase
			Db.local.set('currentSetupPage', currentPage)
			log '  changed to: ', currentPage
		if currentPage is 'setup0' # Setup team and round time
			hideMap()
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
			showMap()
			Obs.observe ->
				if mapReady.get()
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
					window.boundaryRectangle = L.rectangle([loc1, loc2], {color: "#ff7800", weight: 1})
					boundaryRectangle.addTo(map)
				Obs.onClean ->
					log 'onClean() rectangle + corners'
					if mapReady.get()
						map.removeLayer locationOne if locationOne?
						map.removeLayer locationTwo if locationTwo?
						map.removeLayer boundaryRectangle if boundaryRectangle?
		else if currentPage is 'setup2' # Setup flags
			map.removeLayer locationOne if locationOne?
			map.removeLayer locationTwo if locationTwo?
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
			showMap()
			renderFlags()
			Obs.observe ->
				if mapReady.get()
					loc1 = L.latLng(Db.shared.get('game', 'bounds', 'one', 'lat'), Db.shared.get('game', 'bounds', 'one', 'lng'))
					loc2 = L.latLng(Db.shared.get('game', 'bounds', 'two', 'lat'), Db.shared.get('game', 'bounds', 'two', 'lng'))
					window.boundaryRectangle = L.rectangle([loc1, loc2], {color: "#ff7800", weight: 1})
					boundaryRectangle.addTo(map)
					map.on('contextmenu', addMarkerListener)
				Obs.onClean ->
					log 'onClean() rectangle'
					if mapReady.get()
						map.removeLayer boundaryRectangle if boundaryRectangle?
						map.off('contextmenu', addMarkerListener)
	else
		Dom.text tr("Admin/plugin owner is setting up the game")
		# Show map and current settings

# Listener that checks for clicking the map
addMarkerListener = (event) ->
	log 'click: ', event
	Server.send 'addMarker', event.latlng, !->
		# TODO fix predict function
		log 'test prediction add marker'
		Db.shared.set 'flags', event.latlng.lat.toString()+'_'+event.latlng.lng.toString(), {location: event.latlng}
		
# Update the play area square thing
markerDragged = ->
	if mapReady.get()
		Server.send 'setBounds', window.locationOne.getLatLng(), window.locationTwo.getLatLng(), !->
			log 'Predict function setbounds?'
	
# Compare 2 locations to see if they are the same
sameLocation = (location1, location2) -> location1? and location2? and location1.lat is location2.lat and location1.lng is location2.lng
	
# Hide the map
hideMap = ->
	log 'hidemap'
	map = document.getElementById("map")
	if mapReady.get()
		map.style.visibility = 'hidden'
		map.style.opacity = '0'
# Show the map
showMap = ->
	log 'showmap'
	map = document.getElementById("map")
	if mapReady.get()
		map.style.visibility = 'visible'
		map.style.opacity = '1'