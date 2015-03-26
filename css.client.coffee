Dom.css
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