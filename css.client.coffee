Dom.css
# Main element
	'main':
		padding: '0'
		display: 'flex'
		flexDirection: 'column'
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
		flexGrow: '1'
		flexShrink: '1'
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
		display: 'flex'
		flexDirection: 'row'
		flexGrow: '0'
		flexShrink: '0'
	'.stepbar-middle': # The middle section
		flexGrow: '1'
		flexShrink: '1'
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		overflow: 'hidden'
	'.stepbar-button': # A button with an arrow
		borderColor: 'inherit'
		fontSize: '16px'
		color: '#EFEFEF'
		flexGrow: '0'
		flexShrink: '0'
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
		flexGrow: '1'
		flexShrink: '1'
	'.team-button':
		flexGrow: '0'
		flexShrink: '0'
		width: '50px'
		height: '50px'
		lineHeight: '50px'
		marginLeft: '2px'
		fontSize: '25px'
		textAlign: 'center'
		backgroundColor: '#CCCCCC'
	'.team-button-current':
		backgroundColor: '#0077cf'
		color: '#FFFFFF'
