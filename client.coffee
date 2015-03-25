Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
#try
#    Mapbox = require 'mapbox'
#catch error
#    log "MapBox javascript not loaded correctly"

exports.render = ->
	Dom.h2 "Hello, World!"
	
	# Load the map
	loadMap()

# Load the javascript necessary for the map
loadMap = ->
	log "loadMap started"
	
	# Insert map element	
	mapelement = document.createElement "div"
	mapelement.setAttribute 'id', 'map'
	mapelement.style.height = '300px'
	mainElement = document.getElementsByTagName("main")[0]
	mainElement.insertBefore(mapelement, mainElement.childNodes[0])
	###
	Dom.div ->
		Dom.style
			display_: 'box'
			height: '100%'
			width: '100%'
		Dom.text tr("hallo")
		Dom.prop 'tabindex', 3
		Dom.prop 'id', 'map'
		Dom.prop 'class', 'hey'
	###
	# Only insert these the first time
	if(not document.getElementById("mapboxJavascript")?)
		log "  Started loading javascript and CSS"
		# Insert CSS
		css = document.createElement "link"
		css.setAttribute "rel", "stylesheet"
		css.setAttribute "type", "text/css"
		css.setAttribute "id", "mapboxCSS"
	#	css.setAttribute "href", "https://api.tiles.mapbox.com/mapbox-gl-js/v0.6.0/mapbox-gl.css" 	# MapBox with vector images
		css.setAttribute "href", "https://api.tiles.mapbox.com/mapbox.js/v2.1.6/mapbox.css"			# MapBox with tiles
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
	#	javascript.setAttribute 'src', 'https://api.tiles.mapbox.com/mapbox-gl-js/v0.6.0/mapbox-gl.js' 	# MapBox with vector images
		javascript.setAttribute 'src', 'https://api.tiles.mapbox.com/mapbox.js/v2.1.6/mapbox.js'		# MapBox with tiles
		document.getElementsByTagName('head')[0].appendChild javascript
	else
		setupMap()
		
# Initialize the map and draw stuff
setupMap = ->
	log "Initializing MapBox map"
	L.mapbox.accessToken = 'pk.eyJ1Ijoibmx0aGlqczQ4IiwiYSI6IndGZXJaN2cifQ.4wqA87G-ZnS34_ig-tXRvw'
	map = L.mapbox.map('map', 'nlthijs48.lei130kj').setView([40, -74.50], 9)
	layer = L.mapbox.tileLayer('nlthijs48.lei130kj')
	marker = L.marker([40, -74.50]).addTo(map)
	
	#layer.on('ready', function() {})

	
	
	
	
	

	
	
	
	
	
	
	