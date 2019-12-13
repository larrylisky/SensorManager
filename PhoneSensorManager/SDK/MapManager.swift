//
//  MapManager.swift
//  Dashphone
//
//  Created by Larry Li on 8/14/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
//  Usage:
//
//  In global context...
//
//      let mm = MapManager()
//
//  In viewDidLoad()...
//
//      mm.attachMap(self.view)
//
//          ... // instantiate desired gestures and assign delegate
//
//      mm.addGesture(gesture)
//
//          ...
//
//      mm.start

import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxGeocoder
import UserNotifications


private typealias RouteRequestSuccess = (([Route]) -> Void)
private typealias RouteRequestFailure = ((NSError) -> Void)


class MapManager : NSObject {
       
    // Default map zoom level
    var defaultZoomLevel : Double = 16.0
    
    // Default map style
    var defaultStyle = DayStyle()
    
    // User tracking mode
    private(set) var userTrackingMode: MGLUserTrackingMode = .followWithHeading
    
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
    
    private var _currentCars = [CustomPointAnnotation]()

    // Trip points publically read-only
    private(set) var tripPoints : [CLLocationCoordinate2D] = []
    
    // Trip in progress is publically read-only
    private(set) var tripInProgress : Bool = false
    
    // Container view
    var view : UIView?
    
    // mapView
    var mapView: NavigationMapView?
    
    // Waypoints
    var waypoints: [Waypoint] = [] {
        didSet {
            waypoints.forEach {
                $0.coordinateAccuracy = -1
            }
        }
    }
    
    // Routes
    var routes: [Route]? {
        didSet {
            guard let routes = routes,
                let current = routes.first else { mapView?.removeRoutes(); return }
            mapView?.showRoutes(routes)
            mapView?.showWaypoints(current)
        }
    }
    
    //==========================================================
    // MARK: - init()
    // Constructor
    //==========================================================
    override init() {
        super.init()
        requestAuthorization()
        // Setup periodic timer to process data; keep it at 3.0 sec so that the
        // car icons will be sensitive to tap
        Timer.scheduledTimer(timeInterval: 5.0, target: self,
                             selector: #selector(self.periodic), userInfo: nil, repeats: true)
    }
    
    //==========================================================
    // MARK: - init(_ view: UIView)
    // Init with a view
    //==========================================================
    init(_ view: UIView) {
        super.init()
        requestAuthorization()
        attachMap(to: view)
        mapView?.setUserTrackingMode(userTrackingMode, animated: false, completionHandler: nil)
        mapView?.setZoomLevel(defaultZoomLevel, animated: false)
        
        // Setup periodic timer to process data; keep it at 3.0 sec so that the
        // car icons will be sensitive to tap
        Timer.scheduledTimer(timeInterval: 5.0, target: self,
                             selector: #selector(self.periodic), userInfo: nil, repeats: true)
    }
    
    //==========================================================
    // MARK: - func requestAuthorization()
    // Request authorization
    //==========================================================
    func requestAuthorization() {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _,_ in
                DispatchQueue.main.async {
                    CLLocationManager().requestWhenInUseAuthorization()
                }
            }
        }
    }
    

    //==========================================================
    // MARK: - attachMap(to: UIView?)
    // Attach a UIView to display the map
    //==========================================================
    func attachMap(to: UIView?) {
        DispatchQueue.main.async {
            if let view = to {
                self.mapView?.removeFromSuperview()
                if self.mapView == nil {
                    self.mapView = NavigationMapView(frame: view.bounds)
                    self.mapView?.showsUserLocation = false
                    self.mapView?.delegate = self
                }
                if let mapView = self.mapView {
                    self._configureMapView(mapView)
                    mapView.frame = view.bounds
                    view.insertSubview(mapView, at: 0)
                }
                self.view = view
            }
        }
    }
    
    //==========================================================
    // MARK: - detachMap()
    // Detech map from parent view
    //==========================================================
    func detachMap() {
        if let mapView = self.mapView {
            mapView.removeFromSuperview()
        }
    }
    
    //==========================================================
    // MARK: - recenterMap()
    // Recenter map
    //==========================================================
    func recenterMap() {
        mapView?.recenterMap()
    }
    
    //==========================================================
    // MARK: - periodic()
    // Periodic timer callback
    //==========================================================
    @objc func periodic() {
        sys.log("MapManager", text: "periodic() called to handle annotation\n")
        updateNearbyCars()
    }
    
    //==========================================================
    // MARK: - addGesture(_ gesture: UITapGestureRecognizer)
    // Attach a gesture to the mapView - delegate should be
    // assigned by the caller of this function
    //==========================================================
    func addGesture(_ gesture: UITapGestureRecognizer) {
        mapView?.addGestureRecognizer(gesture)
    }
    
    //==========================================================
    // MARK: - removeGesture(_ gesture: UIGestureRecognizer)
    // Detach a gesture to the mapView - delegate should be
    // assigned by the caller of this function
    //==========================================================
    func removeGesture(_ gesture: UIGestureRecognizer) {
        mapView?.removeGestureRecognizer(gesture)
    }
    
    //==========================================================
    // MARK: - currentTrackingMode() -> MGLUserTrackingMode?
    // Returns current user tracking mode
    //==========================================================
    func currentTrackingMode() -> MGLUserTrackingMode? {
        return mapView?.userTrackingMode
    }
    
    //==========================================================
    // MARK: - currentUserLocation() -> CLLocation?
    // Returns current user location
    //==========================================================
    func currentUserLocation() -> CLLocation? {
        return mapView?.userLocation?.location
    }
    
    //==========================================================
    // MARK: - setCompassCenter(_ center: CGPoint)
    // Attach a gesture to the mapView - delegate should be
    // assigned by the caller of this function
    //==========================================================
    func setCompassCenter(_ center: CGPoint) {
        mapView?.compassView.center = center
    }
    
    //==========================================================
    // MARK: - applyStyle(_ style: MapboxNavigation.Style)
    // Apply MapboxNavigation.Style
    //==========================================================
    func applyStyle(_ style: MapboxNavigation.Style) {
        style.apply()
    }
    
    //==========================================================
    // MARK: - applyDefaultStyle()
    // Apply MapboxNavigation.Style
    //==========================================================
    func applyDefaultStyle() {
        defaultStyle.apply()
    }
    
    //==========================================================
    // MARK: - clearMap()
    // clear the map of annotation and waypoints
    //==========================================================
    func clearMap() {
        mapView?.removeRoutes()
        mapView?.removeWaypoints()
        waypoints.removeAll()
        sys.log("MapManager", text: "cleared map\n")

    }
    
    //==========================================================
    // MARK: - requestRoute()
    // Request route
    //==========================================================
    func requestRoute() {
        guard waypoints.count > 0 else { return }
        guard let mapView = mapView else { return }
        
        let userWaypoint = Waypoint(location: mapView.userLocation!.location!, heading: mapView.userLocation?.heading, name: "User location")
        waypoints.insert(userWaypoint, at: 0)
        
        let options = NavigationRouteOptions(waypoints: waypoints)
        
        _requestRoute(with: options, success: _defaultSuccess, failure: _defaultFailure)
    }
    
    
    //==========================================================
    // MARK: - addAnnotations(_ annotations: [CustomPointAnnotation])
    // Add annotations
    //==========================================================
    func addAnnotations(_ annotations: [CustomPointAnnotation]) {
        mapView?.addAnnotations(annotations)
    }
    
    
    //==========================================================
    // MARK: - removeAnnotations(_ annotations: [CustomPointAnnotation])
    // Remove annotations
    //==========================================================
    func removeAnnotations(_ annotations: [CustomPointAnnotation]) {
        mapView?.removeAnnotations(annotations)
    }
    
    //==========================================================
    // MARK: - updateAnnotation(_ annotations: [CustomPointAnnotation])
    // Update annotations after they have been added.  Old ones
    // must be removed first...
    //==========================================================
    func updateAnnotation(_ annotations: [CustomPointAnnotation]) {
        removeAnnotations(annotations)
        addAnnotations(annotations)
    }
    
    //==========================================================
    // MARK: - setTrackingMode(_ mode: MGLUserTrackingMode, animated: Bool = true, completion: @escaping (()->Void) )
    // setTrackingMode
    //==========================================================
    func setTrackingMode(_ mode: MGLUserTrackingMode, animated: Bool = true, completion: @escaping (()->Void) ) {
        mapView?.setUserTrackingMode(mode, animated: animated, completionHandler: {
            sys.log("MapManager", text: "setTrackingMode to \(mode)\n")
            self.userTrackingMode =  mode
            completion()
        })
    }
    
    
    //==========================================================
    // MARK: - setZoomLevel(_ zoomLevel: Double, animated: Bool)
    // setZoomLevel
    //==========================================================
    func setZoomLevel(_ zoomLevel: Double, animated: Bool) {
        mapView?.setZoomLevel(zoomLevel, animated: animated)
    }
    
    
    //==========================================================
    // MARK: - _configureMapView(_ mapView: NavigationMapView)
    // Configure the map view
    //==========================================================
    private func _configureMapView(_ mapView: NavigationMapView) {
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        mapView.navigationMapViewDelegate = self
        mapView.userTrackingMode = userTrackingMode
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.logoView.isHidden = true
    }
    
    //==========================================================
    // MARK: - _defaultSuccess
    // Directions Request Handlers
    //==========================================================
    private lazy var _defaultSuccess: RouteRequestSuccess = { [weak self] (routes) in
        sys.log("MapManager", text: "_requestRoute - succeeeded\n")

        guard let current = routes.first else { return }
        self?.mapView?.removeWaypoints()
        self?.routes = routes
        self?.waypoints = current.routeOptions.waypoints
    }
    
    //==========================================================
    // MARK: - _defaultFailure
    //==========================================================
    private lazy var _defaultFailure: RouteRequestFailure = { [weak self] (error) in
        sys.log("MapManager", text: "_requestRoute - failed\n")

        self?.routes = nil //clear routes from the map
        print(error.localizedDescription)
        sys.showAlert(title: "Route request failed", message: error.localizedDescription, prompt: "Ok")
    }
    
    
    //==========================================================
    // MARK: - _requestRoute(with options: RouteOptions, success: @escaping RouteRequestSuccess, failure: RouteRequestFailure?)
    // Private request route
    //==========================================================
    private func _requestRoute(with options: RouteOptions, success: @escaping RouteRequestSuccess, failure: RouteRequestFailure?) {
        sys.log("MapManager", text: "_requestRoute\n")

        let handler: Directions.RouteCompletionHandler = { (waypoints, routes, error) in
            if let error = error { failure?(error) }
            guard let routes = routes else { return }
            return success(routes)
        }
        
        // Calculate route offline if an offline version is selected
        let shouldUseOfflineRouting = Settings.selectedOfflineVersion != nil
        Settings.directions.calculate(options, offline: shouldUseOfflineRouting, completionHandler: handler)
    }
    
    //==========================================================
    // MARK: - startTrip()
    // Start a trip given a destination
    //==========================================================
    open func startTrip() {
        tripPoints.removeAll()
        tripInProgress = true
    }
    
    
    //==========================================================
    // MARK: - stopTrip()
    // Stop a trip
    //==========================================================
    open func stopTrip() {
        tripInProgress = false
    }
    
    
    //==========================================================
    // MARK: - isTripInProgress() -> Bool
    // Returns true if trip is in progress
    //==========================================================
    open func isTripInProgress() -> Bool {
        return tripInProgress
    }
    
    
    //==========================================================
    // MARK: - updateProgress()
    // Update trip points
    //==========================================================
    open func updateProgress() {
        if tripInProgress {
            let coordinate = CLLocationCoordinate2D(
                latitude: sys.sensor.data.latitude,
                longitude: sys.sensor.data.longitude)
            tripPoints.append(coordinate)
        }
    }
    
    
    //==========================================================
    //  MARK: - currentLocation() -> CLLocation?
    //  Returns current location as CLLocation
    //==========================================================
    open func currentLocation() -> CLLocation? {
        if let location = sys.sensor.currentLocation {
            return location
        }
        else {
            return nil
        }
        /*
        if let location = mapView?.userLocation?.location {
            return location
        }
        else if let location = sys.sensor.currentLocation {
            return location
        }
        else {
            return nil
        }
        */
    }
    
    //==========================================================
    //  MARK: - currentHeading() -> CLHeading?
    //  Returns current user heading
    //==========================================================
    open func currentHeading() -> CLHeading? {
        if let heading = sys.sensor.currentHeading {
            return heading
        }
        else {
            return nil
        }
        /*
        if let heading = mapView?.userLocation?.heading {
            return heading
        }
        else if let heading = sys.sensor.currentHeading {
            return heading
        }
        else {
            return nil
        }
        */
    }
    
    
    //==========================================================
    //  MARK: - currentDirection() -> CLLocationDirection?
    //  Return current map direction
    //==========================================================
    func currentDirection() -> CLLocationDirection? {
        if let direction = mapView?.direction {
            return direction
        }
        else {
            return nil
        }
    }

    
    //==========================================================
    //  MARK: - findPlaces(_ name: String, options: ForwardGeocodeOptions, nearest:Bool = false, completion: @escaping ([GeocodedPlacemark])->Void)
    //  Find candidate or nearest places given a string
    //  Candidate geomarks passsed to completion handler
    //==========================================================
    open func findPlaces(_ name: String, options: ForwardGeocodeOptions, nearest:Bool = false, completion: @escaping ([GeocodedPlacemark])->Void) {
        
        sys.log("MapManager", text: "findPlaces by string=\(name)\n")

        var found : [GeocodedPlacemark] = []

        let _ = Geocoder.shared.geocode(options) { (placemarks, attribution, error) in
            if let places = placemarks, !places.isEmpty {
                if let currentLocation = self.currentLocation(), nearest {
                    var place = places[0]
                    var distance = place.location?.distance(from: currentLocation)
                    for target in placemarks! {
                        let targetDist = target.location?.distance(from: currentLocation)
                        if (targetDist! < distance!) {
                            distance = targetDist
                            place = target
                        }
                    }
                    found.append(place)
                    sys.log("MapManager", text: "findPlaces found nearest place=\(place.name) using string=\(name)\n")

                }
                else {
                    for place in places {
                        sys.log("MapManager", text: "findPlaces found place=\(place.name) using string=\(name)\n")
                        found.append(place)
                    }
                }
            }
            sys.log("MapManager", text: "findPlaces found \(found.count) places going by string=\(name)\n")
            completion(found)
        } // closure
    }
    
    
    //==========================================================
    //  MARK: - getDirections(_ to: GeocodedPlacemark, completion: @escaping ([Waypoint]?, [Route]?)->Void)
    //  Given a geomark, generate routes for turn-by-turn
    //  navigation
    //==========================================================
    open func getDirections(_ to: GeocodedPlacemark, completion: @escaping ([Waypoint]?, [Route]?)->Void) {
        
        sys.log("MapManager", text: "getDirections to \(to.name)\n")

        var waypoints : [Waypoint] = []
        
        // Setup endpoint for the direction
        let coordinates = to.location!.coordinate
        let endpoint = Waypoint(coordinate: coordinates, name: to.name)
        waypoints.append(endpoint)
        
        // Setup starting point for the direction
        if let currentLocation = currentLocation() {
            let startpoint = Waypoint(location: currentLocation, heading: currentHeading(), name: "User location")
            waypoints.insert(startpoint, at: 0)
        }
        else {
            sys.log("MapManager", text: "getDirections found currentLocation = nil\n")
        }
        
        // Setup route request and calculate; result passed onto completion
        let options = NavigationRouteOptions(waypoints: waypoints)
        options.allowsUTurnAtWaypoint = allowsUTurnAtWaypoint
        options.distanceMeasurementSystem = distanceMeasurementSystem
        options.includesAlternativeRoutes = includesAlternativeRoutes
        options.includesSpokenInstructions = includesSpokenInstructions
        options.includesSteps = includesSteps
        let shouldUseOfflineRouting = Settings.selectedOfflineVersion != nil
        Settings.directions.calculate(options, offline: shouldUseOfflineRouting, completionHandler: { (waypoints, routes, error) in
            if error == nil {
                sys.log("MapManager", text: "getDirections found \(String(describing: routes?.count)) routes\n")
                if let waypoints = waypoints {
                    self.waypoints = waypoints
                }
                if let routes = routes {
                    self.routes = routes
                }
                completion(waypoints, routes)
            }
            else if let error = error {
                sys.log("MapManager", text: "getDirections returned error=\(error.localizedDescription)\n")
            }
        })
    }
    
    
    //==========================================================
    //  MARK: - whatsNearMe(coordinate: CLLocationCoordinate2D, completion: @escaping ([GeocodedPlacemark]?)->Void)
    //  Given a CLLocationCoordinate2D, find a collection of what's near
    //==========================================================
    open func whatsNearMe(coordinate: CLLocationCoordinate2D, completion: @escaping ([GeocodedPlacemark]?)->Void) {
        sys.log("MapManager", text: "Checking whatsNearMe by CLLocationCoordinate2D...\n")

        let options = ReverseGeocodeOptions(coordinate: coordinate)
        options.allowedISOCountryCodes = allowedISOCountryCodes
        options.maximumResultCount = maximumReverseResultCount
        options.allowedScopes = [.pointOfInterest, .landmark]
        _ = Geocoder.shared.geocode(options) { (placemarks, attribution, error) in
            if error == nil {
                sys.log("MapManager", text: "whatsNearMe by CLLocationCoordinate2D found \(String(describing: placemarks?.count)) places\n")
                completion(placemarks)
            }
            else if let error = error {
                sys.log("MapManager", text: "whatsNearMe by CLLocationCoordinate2D returned error=\(error.localizedDescription)\n")
            }
        }
        
    }
    
    //==========================================================
    //  MARK: - whatsNearMe(location: CLLocation, completion: @escaping ([GeocodedPlacemark]?)->Void)
    //  Given a CLLocation, find a collection of what's near
    //==========================================================
    open func whatsNearMe(location: CLLocation, completion: @escaping ([GeocodedPlacemark]?)->Void) {
        sys.log("MapManager", text: "Checking whatsNearMe by CLLocation...\n")

        let options = ReverseGeocodeOptions(location: location)
        options.allowedISOCountryCodes = allowedISOCountryCodes
        options.maximumResultCount = maximumReverseResultCount
        _ = Geocoder.shared.geocode(options) { (placemarks, attribution, error) in
            if error == nil {
                sys.log("MapManager", text: "whatsNearMe by CLLocation found \(String(describing: placemarks?.count)) places\n")
                completion(placemarks)
            }
            else if let error = error {
                sys.log("MapManager", text: "whatsNearMe by CLLocation returned error=\(error.localizedDescription)\n")
            }
        }
    }
    
    
    //==========================================================
    //  MARK: - snapShotMap(_ size: CGSize, zoomLevel: Double, completion: @escaping (UIImage?, Error?)->Void)
    //  Take a map snapshot of current location with completion
    //==========================================================
    open func snapShotMap(_ size: CGSize, zoomLevel: Double, completion: @escaping (UIImage?, Error?)->Void) {
        if let current = currentLocation() {
            sys.log("MapManager", text: "Map snapshotting...\n")
            let center = current.coordinate
            let mapView = MGLMapView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            mapView.setCenter(center, zoomLevel: zoomLevel, animated: false)
            
            let options = MGLMapSnapshotOptions(styleURL: mapView.styleURL, camera: mapView.camera, size: mapView.bounds.size)
            options.zoomLevel = mapView.zoomLevel
            
            var snapshotter: MGLMapSnapshotter? = MGLMapSnapshotter(options: options)
            snapshotter?.start { (snapshot, error) in
                sys.log("MapManager", text: "Map snapshot successful\n")
                snapshotter = nil
                completion(snapshot?.image, error)
            }
        }
        else {
            sys.log("MapManager", text: "Map snapshot failed due to nil currentLocation\n")
        }
    }

    //==========================================================
    //  MARK: - updateNearbyCars()
    //  update display of nearby cars
    //==========================================================
    func updateNearbyCars() {
        let cars = sys.nearbyUsers()
        removeAnnotations(_currentCars)
        _currentCars = cars
        addAnnotations(_currentCars)
    }
    
    
    //==========================================================
    //  MARK: - _Error(_ code: Int, text: String) -> NSError 
    //  Return a specified error
    //==========================================================
    private func _Error(_ code: Int, text: String) -> NSError {
        return NSError(domain: "ai.dashphone", code: code, userInfo: [NSLocalizedDescriptionKey: text])
    }
}


//--------------------------------------------------------------
//  MARK: - MGLMapViewDelegate extension
//--------------------------------------------------------------
extension MapManager: MGLMapViewDelegate {
    
    //==========================================================
    // MARK: - mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle)
    // When map loading is finished; show route and waypoints
    //==========================================================
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        guard mapView == self.mapView else {
            return
        }
        self.mapView?.localizeLabels()
        // Show routes and waypoints
        if let routes = routes, let currentRoute = routes.first, let coords = currentRoute.coordinates {
            mapView.setVisibleCoordinateBounds(MGLPolygon(coordinates: coords, count: currentRoute.coordinateCount).overlayBounds, animated: false)
            self.mapView?.showRoutes(routes)
            self.mapView?.showWaypoints(currentRoute)
        }
    }
    
    
    //==========================================================
    // MARK: - mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView?
    // Show or add custom annotation to the map
    //==========================================================
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {

        var view : MGLAnnotationView?

        if annotation is MGLUserLocation && mapView.userLocation != nil {
            return CustomUserLocationAnnotationView()
        }
        else if let point = annotation as? CustomPointAnnotation,
            let reuseIdentifier = point.reuseIdentifier {
            
            if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) {
                // The annotatation image has already been cached, just reuse it.
                view = annotationView
            } else {
                // Create a new annotation view
                let newView : MGLAnnotationView = MGLAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                let imageView = UIImageView(image: point.image)
                imageView.layer.anchorPoint = CGPoint(x:1.0, y:1.0)
                newView.addSubview(imageView)
                view = newView
            }
            
            if let direction = currentDirection() {
                let rotation = -MGLRadiansFromDegrees(direction - point.heading)
                view?.layer.setAffineTransform(CGAffineTransform.identity.rotated(by: CGFloat(rotation)))
            }
        }
        return view
    }
    
    //==========================================================
    // MARK: - mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation)
    // Handle when annotation is clicked
    //==========================================================
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        if let point = annotation as? CustomPointAnnotation {
            sys.log("MapManager", text: "didSelect car annotation titled \(String(describing: point.title)) at \(point.coordinate)\n")
        }
    }
    
    //==========================================================
    // MARK: - mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool
    // Return if annotation should show callout - always
    //==========================================================
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
}

//--------------------------------------------------------------
// MARK: - NavigationMapViewDelegate extension
//--------------------------------------------------------------
extension MapManager: NavigationMapViewDelegate {
    
    //==========================================================
    // MARK: - navigationMapView(_ mapView: NavigationMapView, didSelect waypoint: Waypoint)
    // When a waypoint is selected, remove waypoint
    //==========================================================
    func navigationMapView(_ mapView: NavigationMapView, didSelect waypoint: Waypoint) {
        guard let routeOptions = routes?.first?.routeOptions else { return }
        let modifiedOptions = routeOptions.without(waypoint: waypoint)
        
        _presentWaypointRemovalActionSheet { [unowned self] _ in
            self._requestRoute(with:modifiedOptions, success: self._defaultSuccess, failure: self._defaultFailure)
        }
    }
    
    //==========================================================
    // MARK: - navigationMapView(_ mapView: NavigationMapView, didSelect route: Route)
    // When a route is selected - remove route
    //==========================================================
    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        guard let routes = routes else { return }
        guard let index = routes.firstIndex(where: { $0 == route }) else { return }
        self.routes!.remove(at: index)
        self.routes!.insert(route, at: 0)
    }
    
    //==========================================================
    // MARK: - _presentWaypointRemovalActionSheet(completionHandler approve: @escaping ((UIAlertAction) -> Void))
    // Show action sheet to get user confirmation
    //==========================================================
    private func _presentWaypointRemovalActionSheet(completionHandler approve: @escaping ((UIAlertAction) -> Void)) {
        let title = NSLocalizedString("REMOVE_WAYPOINT_CONFIRM_TITLE", value: "Remove Waypoint?", comment: "Title of sheet confirming waypoint removal")
        let message = NSLocalizedString("REMOVE_WAYPOINT_CONFIRM_MSG", value: "Do you want to remove this waypoint?", comment: "Message of sheet confirming waypoint removal")
        let removeTitle = NSLocalizedString("REMOVE_WAYPOINT_CONFIRM_REMOVE", value: "Remove Waypoint", comment: "Title of alert sheet action for removing a waypoint")
        let cancelTitle = NSLocalizedString("REMOVE_WAYPOINT_CONFIRM_CANCEL", value: "Cancel", comment: "Title of action for dismissing waypoint removal confirmation sheet")
        
        let remove = UIAlertAction(title: removeTitle, style: .destructive, handler: approve)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
        
        sys.showActionSheet(title: title, message: message, actions: [remove, cancel])
    }
}


//--------------------------------------------------------------
// MARK: - CustomPointAnnotation class
//--------------------------------------------------------------
class CustomPointAnnotation: NSObject, MGLAnnotation, NSCopying {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var image: UIImage?
    var reuseIdentifier: String?
    var heading: Double = 0.0    // degree
    
    //==========================================================
    // MARK: - init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?)
    //==========================================================
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
    
    //==========================================================
    // MARK: - copy(with zone: NSZone? = nil) -> Any
    // Create a deep copy of annotation
    //==========================================================
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = CustomPointAnnotation(coordinate: coordinate, title: title, subtitle: subtitle)
        return copy
    }
}



//--------------------------------------------------------------
// MARK: - Customized user location icon
//--------------------------------------------------------------
class CustomUserLocationAnnotationView: MGLUserLocationAnnotationView {
    let size: CGFloat = 24
    var dot: CALayer!
    var arrow: CAShapeLayer!
    
    //==========================================================
    // MARK: - update()
    // update is a method inherited from MGLUserLocationAnnotationView.
    // It updates the appearance of the user location annotation when
    // needed. This can be called many times a second, so be careful
    // to keep it lightweight.
    //==========================================================
    override func update() {
        if frame.isNull {
            frame = CGRect(x: 0, y: 0, width: size, height: size)
            return setNeedsLayout()
        }
        
        // Check whether we have the user’s location yet.
        if CLLocationCoordinate2DIsValid(userLocation!.coordinate) {
            setupLayers()
            updateHeading()
        }
    }
    
    //==========================================================
    // MARK: - updateHeading()
    // Update user heading
    //==========================================================
    private func updateHeading() {
        // Show the heading arrow, if the heading of the user is available.
        if let heading = userLocation!.heading?.trueHeading {
            arrow.isHidden = false
          //  arrow.isHidden = true
            
            // Get the difference between the map’s current direction and the user’s heading, then convert it from degrees to radians.
            let rotation: CGFloat = -MGLRadiansFromDegrees(mapView!.direction - heading)
            
            // If the difference would be perceptible, rotate the arrow.
            if abs(rotation) > 0.01 {
                // Disable implicit animations of this rotation, which reduces lag between changes.
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                arrow.setAffineTransform(CGAffineTransform.identity.rotated(by: rotation))
                CATransaction.commit()
            }
        } else {
            arrow.isHidden = true
        }
    }
    
    //==========================================================
    // MARK: - setupLayers()
    // Setup the graphics layer
    //==========================================================
    private func setupLayers() {
        // This dot forms the base of the annotation.
        if dot == nil {
            dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            
            // Use CALayer’s corner radius to turn this layer into a circle.
            dot.cornerRadius = size / 2
            dot.backgroundColor = UIColor.blue.cgColor //super.tintColor.cgColor
            dot.borderWidth = 4
            dot.borderColor = UIColor.white.cgColor
            layer.addSublayer(dot)
        }
        
        // This arrow overlays the dot and is rotated with the user’s heading.
        if arrow == nil {
            arrow = CAShapeLayer()
            arrow.path = arrowPath()
            arrow.frame = CGRect(x: 0, y: 0, width: size / 2, height: size / 2)
            arrow.position = CGPoint(x: dot.frame.midX, y: dot.frame.midY)
            arrow.fillColor = dot.borderColor
            layer.addSublayer(arrow)
        }
    }
    
    //==========================================================
    // MARK: - arrowPath() -> CGPath
    // Calculate the vector path for an arrow, for use in a shape layer.
    //==========================================================
    private func arrowPath() -> CGPath {
        let max: CGFloat = size / 2
        let pad: CGFloat = 3
        
        let top =    CGPoint(x: max * 0.5, y: 0)
        let left =   CGPoint(x: 0 + pad,   y: max - pad)
        let right =  CGPoint(x: max - pad, y: max - pad)
        let center = CGPoint(x: max * 0.5, y: max * 0.6)
        
        let bezierPath = UIBezierPath()
        bezierPath.move(to: top)
        bezierPath.addLine(to: left)
        bezierPath.addLine(to: center)
        bezierPath.addLine(to: right)
        bezierPath.addLine(to: top)
        bezierPath.close()
        
        return bezierPath.cgPath
    }
}

