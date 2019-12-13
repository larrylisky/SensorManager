//
//  TripManager.swift
//  Dashphone
//
//  Created by Larry Li on 7/31/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import UserNotifications
import MapboxGeocoder


class TripManager : NSObject {
    
    // Maximum location targets
    open var maximumForwardResultCount : UInt = 5
    
    // Maximum reverse results
    open var maximumReverseResultCount : UInt = 10
    
    // Current destination
    open var destination : GeocodedPlacemark?
    
    // Allow U turns
    open var allowsUTurnAtWaypoint : Bool = false
    
    // Include alternative routes
    open var includesAlternativeRoutes : Bool = true
    
    // Includes spoken instruction
    open var includesSpokenInstructions : Bool = true
    
    // Includes steps
    open var includesSteps : Bool = true
    
    // Distance units: .metric or .imperial
    open var distanceMeasurementSystem : MapboxDirections.MeasurementSystem = .imperial
    
    // Search limited to country code
    // See https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#CA
    open var allowedISOCountryCodes : [String] = ["US"]
    
    // Last encountered error
    open var lastError : NSError?

    // Trip points publically read-only
    private(set) var tripPoints : [CLLocationCoordinate2D] = []

    // Trip in progress is publically read-only
    private(set) var tripInProgress : Bool = false
    
    
    ////////////////////////////////////////////////////////////
    

    
    
    //==========================================================
    // Start a trip given a destination
    //==========================================================
    open func startTrip() {
        tripPoints.removeAll()
        tripInProgress = true
    }
    
    
    //==========================================================
    // Start a trip given a destination
    //==========================================================
    open func stopTrip() {
        tripInProgress = false
    }
    
    
    //==========================================================
    // Returns true if trip is in progress
    //==========================================================
    open func isTripInProgress() -> Bool {
        return tripInProgress
    }
    
    
    //==========================================================
    // Update trip points
    //==========================================================
    open func updateProgress() {
        if tripInProgress {
            let coordinate = CLLocationCoordinate2D(
                latitude: sys.sensor.sensorData.lattitude,
                longitude: sys.sensor.sensorData.longitude)
            tripPoints.append(coordinate)
        }
    }
    
    
    //==========================================================
    //  Returns current location as CLLocation
    //==========================================================
    open func currentLocation() -> CLLocation {
        return sys.sensor.currentLocation!
    }
    
    //==========================================================
    //  Returns current user heading
    //==========================================================
    open func currentHeading() -> CLHeading {
        return sys.sensor.currentHeading!
    }
    
    //==========================================================
    //  Find candidate or nearest places given a string
    //  Candidate geomarks passsed to completion handler
    //==========================================================
    open func findPlaces(_ name: String, nearest:Bool = true, completion: @escaping ([GeocodedPlacemark])->Void) {
        
        var found : [GeocodedPlacemark] = []
        
        let options = ForwardGeocodeOptions(query: name)
        options.autocompletesQuery = true
        options.focalLocation = currentLocation()
        options.allowedScopes = [.address, .pointOfInterest, .landmark, .place]
        options.maximumResultCount = maximumForwardResultCount
        let _ = Geocoder.shared.geocode(options) { (placemarks, attribution, error) in
            if let places = placemarks, !places.isEmpty {
                if nearest {
                    var place = places[0]
                    var distance = place.location?.distance(from: self.currentLocation())
                    for target in placemarks! {
                        let targetDist = target.location?.distance(from: self.currentLocation())
                        if (targetDist! < distance!) {
                            distance = targetDist
                            place = target
                        }
                    }
                    found.append(place)
                }
                else {
                    for place in places {
                        found.append(place)
                    }
                }
            }
            completion(found)
        } // closure
    }
    
    
    //==========================================================
    //  Given a geomark, generate routes for turn-by-turn
    //  navigation
    //==========================================================
    open func getDirections(_ to: GeocodedPlacemark, completion: @escaping ([Waypoint]?, [Route]?)->Void) {

        var waypoints : [Waypoint] = []

        // Setup startpoint and endpoint for the direction
        let coordinates = to.location!.coordinate
        let endpoint = Waypoint(coordinate: coordinates, name: to.name)
        waypoints.append(endpoint)
        let startpoint = Waypoint(location: currentLocation(), heading: currentHeading(), name: "User location")
        waypoints.insert(startpoint, at: 0)
        
        // Setup route request and calculate; result passed onto completion
        let options = NavigationRouteOptions(waypoints: waypoints)
        options.allowsUTurnAtWaypoint = allowsUTurnAtWaypoint
        options.distanceMeasurementSystem = distanceMeasurementSystem
        options.includesAlternativeRoutes = includesAlternativeRoutes
        options.includesSpokenInstructions = includesSpokenInstructions
        options.includesSteps = includesSteps
        let shouldUseOfflineRouting = Settings.selectedOfflineVersion != nil
        Settings.directions.calculate(options, offline: shouldUseOfflineRouting, completionHandler: { (waypoints, routes, error) in
            completion(waypoints, routes)
        })
    }
    
    
    //==========================================================
    //  Given a CLLocationCoordinate2D, find a collection of what's near
    //==========================================================
    open func whatsNearMe(coordinate: CLLocationCoordinate2D, completion: @escaping ([GeocodedPlacemark]?)->Void) {

        let options = ReverseGeocodeOptions(coordinate: coordinate)
        options.allowedISOCountryCodes = allowedISOCountryCodes
        options.maximumResultCount = maximumReverseResultCount
        options.allowedScopes = [.pointOfInterest, .landmark]
        _ = Geocoder.shared.geocode(options) { (placemarks, attribution, error) in
            completion(placemarks)
        }
            
    }
    
    //==========================================================
    //  Given a CLLocation, find a collection of what's near
    //==========================================================
    open func whatsNearMe(location: CLLocation, completion: @escaping ([GeocodedPlacemark]?)->Void) {
        
        let options = ReverseGeocodeOptions(location: location)
        options.allowedISOCountryCodes = allowedISOCountryCodes
        options.maximumResultCount = maximumReverseResultCount
        _ = Geocoder.shared.geocode(options) { (placemarks, attribution, error) in
            completion(placemarks)
        }
    }
      
    
    //==========================================================
    //  Take a map snapshot of current location with completion
    //==========================================================
    open func snapShotMap(_ size: CGSize, zoomLevel: Double, completion: @escaping (UIImage?, Error?)->Void) {
        let current = currentLocation()
        let center = current.coordinate
        let mapView = MGLMapView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        mapView.setCenter(center, zoomLevel: zoomLevel, animated: false)
        
        let options = MGLMapSnapshotOptions(styleURL: mapView.styleURL, camera: mapView.camera, size: mapView.bounds.size)
        options.zoomLevel = mapView.zoomLevel
        
        var snapshotter: MGLMapSnapshotter? = MGLMapSnapshotter(options: options)
        snapshotter?.start { (snapshot, error) in
            snapshotter = nil
            completion(snapshot?.image, error)
        }
    }
    
    
    //==========================================================
    //  Return a specified error
    //==========================================================
    private func _Error(_ code: Int, text: String) -> NSError {
        return NSError(domain: "ai.dashphone", code: code, userInfo: [NSLocalizedDescriptionKey: text])
    }
}



