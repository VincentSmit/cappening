Dom.css
# Main content page
	'.bar-button':
		height: "100%"
		width: "50%"
		float: "left"
		color: "white"
		lineHeight: "50px"
		textAlign: "center"
		borderRight: '2px solid rgba(255,255,255,0.3)'
		boxSizing: 'border-box'
		backgroundColor: 'transparent'
	'.bar-button:last-of-type':
		borderRight: '0 none'
	'.bar-button:hover':
		backgroundColor:'rgba(0, 0, 0, 0.1)'	
	'.bar-button:active':
		backgroundColor: 'rgba(0,0,0,0.2) !important'
	'.mapbox-logo':
		display: "none"
# Map element
	'#OpenStreetMap':
		position: 'absolute !important'
		top: '0'
		right: '0'
		bottom: '0'
		left: '0'
		backgroundColor: '#DDD'
# Ensure clicking the shadow of a marker goes to the element below (beacon circle in this case)
	'.leaflet-shadow-pane img':
		pointerEvents: 'none'
# Plugin setup pages
	'.stepbar': # The bar at the top
		color: "white"
		backgroundColor: "#888"
		lineHeight: "50px"
		textAlign: "center"
		zIndex: "5"
		boxShadow: "0 3px 5px 0 rgba(0, 0, 0, 0.2)"
		borderColor: "#EFEFEF"
		fontSize: '19px'
		boxSizing: 'border-box'
		position: 'absolute'
		width: '100%'
		margin: '-8px -8px 0 -8px'
	'.stepbar-middle': # The middle section
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		overflow: 'hidden'
		padding: '0 80px 0 80px'
	'.stepbar-button': # A button with an arrow
		borderColor: 'inherit'
		fontSize: '16px'
		color: '#EFEFEF'
		_flexGrow: '0'
		_flexShrink: '0'
		position: 'absolute'
	'.stepbar-button:hover':
		backgroundColor: '#7C7C7C'
	'.stepbar-button:active':
		backgroundColor: '#767676 !important'
	'.stepbar-left': # The left arrow button
		textAlign: 'left'
		paddingLeft: '38px'
		paddingRight: '10px'
		left: '0'
		top: '0'
	'.stepbar-left::before':
		content: '""' # The left arrow button (pseudo element to create the arrow)
		position: 'absolute'
		display: 'block'
		width: '0'
		margin: '10px 0 0 8px'
		borderRight: '25px solid'
		borderTop: '15px solid transparent'
		borderBottom: '15px solid transparent'
		borderRightColor: 'inherit'
		left: '0'
	'.stepbar-right': # The right arrow button
		textAlign: 'right'
		paddingRight: '38px'
		paddingLeft: '10px'
		right: '0'
		top: '0'
	'.stepbar-right::before': # The right arrow button (pseudo element to create the arrow)
		content: '""'
		position: 'absolute'
		display: 'block'
		width: '0'
		margin: '10px 8px 0 0'
		borderLeft: '25px solid'
		borderTop: '15px solid transparent'
		borderBottom: '15px solid transparent'
		borderLeftColor: 'inherit'
		right: '0'
	'.stepbar-disable': # Class to disable an arrow button
		borderColor: '#A3A3A3'
		backgroundColor: 'transparent !important'
		color: '#A3A3A3'
		cursor: 'default'
	'.stepbar-disable:active':
		backgroundColor: 'transparent !important'
# Team selection elements
	'.team-text':
		margin: '0 10px 5px 0'
	'.team-button':
		float: 'left'
		width: '50px'
		height: '50px'
		lineHeight: '50px'
		margin: '0 2px 2px 0'
		fontSize: '25px'
		textAlign: 'center'
		backgroundColor: '#CCCCCC'
	'.team-button-current':
		backgroundColor: '#0077cf !important'
		color: '#FFFFFF'
# Time unit selection buttons
	'.time-text':
		margin: '0 10px 5px 0'
	'.time-button':
		float: 'left'
		height: '50px'
		lineHeight: '50px'
		margin: '0 2px 2px 0'
		padding: '0 10px 0 10px'
		fontSize: '20px'
		textAlign: 'center'
		backgroundColor: '#CCCCCC'
	'.time-button-current':
		backgroundColor: '#0077cf !important'
		color: '#FFFFFF'
# Infobar at the bottom of the screen
	'.infobar':
		width: '100%'
		position: 'absolute'
		bottom: '0'
		left: '0'
		zIndex: '2000'
		padding: '11px'
		fontSize: '16px'
		boxSizing: 'border-box'
		backgroundColor: '#888888'
		color: 'white'
		_display: 'flex'
		_alignItems: 'center'
# Scores page
	'.teampage':
		fontSize: "20px"
		display: "block"
		borderBottom: "2px solid"
		paddingBottom: "2px"
		textTransform: "uppercase"
		textShadow: "1px 1px 2px #000000"	

# End game page
	'.endGameBar':
		height: "50px"
		width: '100%'
		left: '0'
		position: 'absolute'
		bottom: '15'
		zIndex: '2000'
		padding: '11px'
		fontSize: '16px'
		boxSizing: 'border-box'
		color: 'white'
		_display: 'flex'
		_alignItems: 'center'
		_textShadow: '0 0 5px #000000, 0 0 5px #000000'
	'.restartButton':
		position: 'absolute'
		right: '6px'
		top: '7px'
		backgroundColor: '#ba1a6e'
		padding: '8px'
		textAlign: 'center'
		color: 'white'
		lineHeight: '20px'
		_boxShadow: '0 0 3px rgba(0,0,0,0.5)'
	'.restartButton:hover':
		backgroundColor: '#A71963 !important' 
	'.restartButton:active':
		backgroundColor: '#80134C !important'


#Indication Arrow
	'.indicationArrow':
		width: '30px'
		height: '30px'
		bottom: '10px'
		left: '10px'
		position: 'absolute'
		borderRadius: '15px'
		zIndex: '10'
		_boxShadow: '0 0 6px rgba(255, 255, 255, 0.5)'
	'.indicationArrow:before':
		content: '""'
		display: 'block'
		position: 'absolute'
		width: '6px'
		backgroundColor: 'white'
		top: '15px'
		left: '12px'
		height: '7px'
	'.indicationArrow:after':
		content: '""'
		display: 'block'
		width: '0'
		height: '0'
		top: '5px'
		left: '7px'
		borderBottom: 'solid 10px white'
		borderLeft: 'solid 8px transparent'
		borderRight: 'solid 8px transparent'
		position: 'absolute'
	'.arrowDivText':
		fontSize: '12px'
		color: '#000000'
		fontWeight: 'bold'
		bottom: '2px'
		left: '50px'
		height: '30px'
		position: 'absolute'
		zIndex: '10'
		textShadow: '0 0 4px #FFFFFF, 0 0 4px #FFFFFF'