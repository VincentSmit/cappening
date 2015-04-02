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

exports.render = ->
	#players = Db.shared.peek('players')
	#teams = Db.shared.peek('teams')
		# Set page title
	page = Page.state.get(0)
	page = "Map" if not page?   
	Page.setTitle page
	# Display the correct page
	if page == 'Map'
		mainContent()
	else if page == 'Help'
        helpContent()
    else if page == 'Scores'
        scoresContent()
    else if page == 'Log'
        logContent()
	if !Geoloc.isSubscribed()
		Geoloc.subscribe()
	if Geoloc.isSubscribed()
		state = Geoloc.track()
		location = state.get('latlong');
		if location?
			location = location.split(',')
			marker = L.marker(L.latLng(location[0], location[1]))
			marker.bindPopup("Hier ben ik nu!" + "<br> accuracy: " + state.get('accuracy'))
			marker.addTo(window.map)
		else
			log 'location could not be found'
	

# Load the javascript necessary for the map
loadMap = ->
	log "loadMap started"
	
	# Insert map element
	mapToCreate = not document.getElementById("map")?
	if(mapToCreate)
		mapelement = document.createElement "div"
		mapelement.setAttribute 'id', 'map'
		mapelement.style.width = '100%'
		mapelement.style.position = 'absolute'
		mapelement.style.top = '50px'
		mapelement.style.bottom = '0'
		mapelement.style.left = '0'
		mapelement.style.right = '0'
		mapelement.style.backgroundColor = '#030303'
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
	if L? and L.mapbox?
		log "Initializing MapBox map"
		# Tile version
		L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
		window.map = L.mapbox.map('map', 'nlthijs48.4153ad9d', {zoomControl:false})
		layer = L.mapbox.tileLayer('nlthijs48.4153ad9d')
		setupListeners()
		Obs.observe !->
			renderFlags()

# Setup click events etc
setupListeners = ->
	# Register listener for adding markers
	onClick = (event) ->
		log 'click: ', event
		#marker = L.marker(event.latlng, {draggeble: true, title: 'flag'}).addTo(window.map)
		Server.send 'addMarker', event.latlng, ->
			# TODO fix predict function
			log 'test'
			Db.shared.set 'flags', event.latlng.lat.toString()+'_'+event.latlng.lng.toString(), {location: event.latlng}
	map.on 'contextmenu', onClick

# Add flags to the map
renderFlags = ->	
	Db.shared.observeEach 'flags', (flag) !->
		if window.map?
			lat = flag.get('location', 'lat')
			lng = flag.get('location', 'lng')
			log 'Adding flag: ', flag, ' lat=', lat, ', lng=', lng
			marker = L.marker(L.latLng(lat, lng))
			marker.bindPopup("lat: " + lat + "<br>long: " + lng)
			marker.addTo(window.map)
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
				Page.nav 'Help' 
        #DIV button to help page
		Dom.div !->
			Dom.text "Event Log"
			Dom.cls 'bar-button'
			Dom.onTap !->   
				Page.nav 'Log'
		#DIV button to help page
		Dom.div !->
			Dom.text "Scores"
			Dom.cls 'bar-button'
			Dom.onTap !->   
				Page.nav 'Scores'
		#DIV button to main menu
		Dom.div !->
			Dom.text "10 pnts"
			Dom.cls 'bar-button'
			Dom.onTap !->
				Modal.show tr("Team Points"), !->
					Dom.text tr("Your team has 10 points!")
					
# Home page with map
mainContent = ->
	renderFlags()
	loadMap()
	addBar()

# Help page 
helpContent = ->
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
	#users = Db.shared.ref('users')
	teams = Obs.create
		1: {name: 'red'}
		2: {name: 'yellow'}
	users = Obs.create
		1: {name: 'Lars', score: 10, team: 'red'}
		2: {name: 'Thijs', score: 30, team: 'red'}
		3: {name: 'Sem', score: 9001, team: 'yellow'}
	Dom.div ->
		users.iterate (user) ->
			Dom.text tr("%1 has a score of %2", user.get('name'), user.get('score'))
			Dom.br()
	Dom.br()		
	Dom.text "The scores of all teams:"
	Dom.div ->
		teams.iterate (team) ->
			teamscore = 0
			users.iterate (user) ->
				teamscore = teamscore + user.get('score') if user.get('team') == team.get('name') 			
			Dom.text tr("Team %2 has a score of %1", teamscore, team.get('name'))
			Dom.br()
    
logContent = ->
	Dom.text "The log file of all events"   
	
	
	