Dom.css
# Main element
	'#main':
		padding: '0 !important'
		display_: 'flex'
		_flexDirection: 'column'
	'.container':
		padding: '8px'
# Main content page
	'.bar-button':
		height: "100%"
		width: "25%"
		float: "left"
		color: "white"
		backgroundColor: "#666"
		lineHeight: "50px"
		textAlign: "center"
		verticalAlign: "middle"
	'.bar-button::after':
		content: '""'
		display: 'block'
		width: '1px'
		height: '40px'
		backgroundColor: '#ABABAB'
		margin: '-44px 0 0 0'
		boxShadow: 'none'
	'.bar-button:first-of-type::after':
		display: 'none'
	'.mapbox-logo':
		display: "none"
# Map element
	'#OpenStreetMap':
		width: '100%'
		_flexGrow: '1'
		_flexShrink: '1'
		backgroundColor: '#030303'
# Plugin setup pages
	'.stepbar': # The bar at the top
		color: "white"
		backgroundColor: "#888"
		lineHeight: "50px"
		textAlign: "center"
		zIndex: "5"
		boxShadow: "0 3px 5px 0 rgba(0, 0, 0, 0.2)"
		borderColor: "#EFEFEF"
		fontSize: '20px'
		boxSizing: 'border-box'
		display_: 'flex'
		_flexDirection: 'row'
		_flexGrow: '0'
		_flexShrink: '0'
	'.stepbar-middle': # The middle section
		_flexGrow: '1'
		_flexShrink: '1'
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		overflow: 'hidden'
	'.stepbar-button': # A button with an arrow
		borderColor: 'inherit'
		fontSize: '16px'
		color: '#EFEFEF'
		_flexGrow: '0'
		_flexShrink: '0'
	'.stepbar-button:hover':
		backgroundColor: '#7C7C7C'
	'.stepbar-button:active':
		backgroundColor: '#767676 !important'
	'.stepbar-left': # The left arrow button
		textAlign: 'left'
		paddingLeft: '38px'
		paddingRight: '10px'
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
# Scores page
	'.teampage':
		fontSize: "20px"
		display: "block"
		borderBottom: "2px solid"
		paddingBottom: "2px"
		textTransform: "uppercase"
		textShadow: "1px 1px 2px #000000"
