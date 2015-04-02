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
				Page.nav 'help' 
        #DIV button to help page
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
	
	
	