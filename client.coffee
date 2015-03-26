Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'

exports.render = ->
	# Load the map
	loadMap()
	renderFlags()

# Load the javascript necessary for the map
loadMap = ->
	log "loadMap started"
	
	# Insert map element
	createMap = not document.getElementById("map")?
	if createMap
		mapelement = document.createElement "div"
		mapelement.setAttribute 'id', 'map'
		mapelement.style.width = '100%'
		mapelement.style.position = 'absolute'
		mapelement.style.top = '0'
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
	if not document.getElementById("mapboxJavascript")?
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
	if createMap
		setupMap()
		
# Initialize the map with tiles
setupMap = ->
	log "setupMap"
	if L? and L.mapbox?
		log "Initializing MapBox map"
		# Tile version
		L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
		window.map = L.mapbox.map('map', 'nlthijs48.4153ad9d')
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
			log 'Adding flag: ', flag, ' lat=', flag.get('location', 'lat'), ', lng=', flag.get('location', 'lng')
			marker = L.marker(L.latLng(flag.get('location', 'lat'), flag.get('location', 'lng'))).addTo(window.map)
	, (flag) ->
		-flag.get()
	
	

	
	
	
	
	
	
	