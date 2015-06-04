# General config values (used by client and server)
exports.getConfig = ->
	return {
		beaconPointsTime: 3600000	# Milliseconds between scoring points for a beacon
		beaconHoldScore: 1			# Number of points scored per <pointsTime> by holding a beacon
		beaconValueInitial: 50 		# Initial capture value of a beacon
		beaconValueDecrease: 5		# Value decrease after capture
		beaconValueMinimum: 10		# Minimum beacon value	
	}