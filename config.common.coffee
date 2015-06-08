# General config values (used by client and server)
exports.getConfig = ->
	return {
		beaconPointsTime: 3600000	# Milliseconds between scoring points for a beacon
		beaconHoldScore: 1			# Number of points scored per <pointsTime> by holding a beacon
		beaconValueInitial: 50 		# Initial capture value of a beacon
		beaconValueDecrease: 5		# Value decrease after capture
		beaconValueMinimum: 10		# Minimum beacon value
		onHTTPKey: '0acc7d0fd7ac9ef4133950d3949b81a7' #hash of http secret key	
	}