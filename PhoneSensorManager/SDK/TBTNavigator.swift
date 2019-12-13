//
//  TBTNavigator.swift
//  Dashphone
//
//  Created by Larry Li on 9/24/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
//  Usage:
//
//  1. Embedded an instance ot TBTNavigator in the host view controller.
//  2. As
//
//      var tbtnavigator : TBTNavigator
//
//  override func viewDidLoad() {
//      tbtnavigator.view = self.<view
//      tbtnavigator.containerViewController.self
//


import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxGeocoder
import UserNotifications


class TBTNavigator : NSObject {
    
    // Hosting view controller
    var containerViewController : UIViewController?
    
    // View in the host view controller to attach mapView to
    var view : UIView?
    
    // View in the host view controller to attach Instruction Banner to
    var instructionsBannerView : InstructionsBannerView?
    
    // Route to turn-by-turn navigation to
    var userRoute: Route?

    // Should use simulate location
    var simulateLocation = false
    
    // MapView to be created later at startup
    private var _mapView: NavigationMapView?
    
    // Navigation service
    private var _navigationService : NavigationService!
    
    // Preview index of step, this will be nil if we are not previewing an instruction
    private var _previewStepIndex: Int?
    
    // View that is placed over the instructions banner while we are previewing
    private var _previewInstructionsView: StepInstructionsView?
    
    // Step view controller
    private var _stepsViewController: StepsViewController?
    
    
    //==========================================================
    // MARK: - init()
    //==========================================================
    override init() {
        super.init()
    }
    
    //==========================================================
    // MARK: - deinit
    //==========================================================
    deinit {
        suspendNotifications()
    }
    
    //==========================================================
    // MARK: - setup()
    //==========================================================
    func setup() {
        let locationManager = simulateLocation ? SimulatedLocationManager(route: userRoute!) : NavigationLocationManager()
        _navigationService = MapboxNavigationService(route: userRoute!, locationSource: locationManager, simulating: simulateLocation ? .always : .onPoorGPS)
        _mapView?.delegate = self
        _mapView?.compassView.isHidden = true
          
        instructionsBannerView?.delegate = self
        instructionsBannerView?.swipeable = true

        // Add listeners for progress updates
        resumeNotifications()

        // Start navigation
        _navigationService.start()
        _updateRouteProgress(_navigationService.routeProgress)
          
        // Center map on user
        _mapView?.recenterMap()
    }
    
    //==========================================================
    // Resume notification
    //==========================================================
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(_progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_rerouted(_:)), name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_updateInstructionsBanner(notification:)), name: .routeControllerDidPassVisualInstructionPoint, object: _navigationService.router)
    }

    //==========================================================
    // Suspend notification
    //==========================================================
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerWillReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassVisualInstructionPoint, object: nil)
    }
    
    
    //==========================================================
    // MARK: - attachMap(to: UIView?)
    // Attach a UIView to display the map
    //==========================================================
    func attachMap(to: UIView?) {
        DispatchQueue.main.async {
            if let view = to {
                self._mapView?.removeFromSuperview()
                if self._mapView == nil {
                    self._mapView = NavigationMapView(frame: view.bounds)
                }
                if let mapView = self._mapView {
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
        if let mapView = self._mapView {
            mapView.removeFromSuperview()
        }
    }
    
    //==========================================================
    // MARK: - recenterMap()
    // Recenter map
    //==========================================================
    func recenterMap() {
        _mapView?.recenterMap()
    }
    
    //==========================================================
    // MARK: - _configureMapView(_ mapView: NavigationMapView)
    // Configure the map view
    //==========================================================
    private func _configureMapView(_ mapView: NavigationMapView) {
        mapView.delegate = self
        mapView.compassView.isHidden = true
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
     //   mapView.navigationMapViewDelegate = self
     //   mapView.userTrackingMode = userTrackingMode
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.logoView.isHidden = true
        
        mapView.tracksUserCourse = false
        mapView.userTrackingMode = .none
        mapView.enableFrameByFrameCourseViewTracking(for: 1)
    }
    
    //==========================================================
    // Notifications sent on all location updates
    //==========================================================
    @objc private func _progressDidChange(_ notification: NSNotification) {
        // do not update if we are previewing instruction steps
        guard _previewInstructionsView == nil else { return }
        
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
        
        // Add maneuver arrow
        if routeProgress.currentLegProgress.followOnStep != nil {
            _mapView?.addArrow(route: routeProgress.route, legIndex: routeProgress.legIndex, stepIndex: routeProgress.currentLegProgress.stepIndex + 1)
        } else {
            _mapView?.removeArrow()
        }
        
        // Update the top banner with progress updates
        instructionsBannerView?.updateDistance(for: routeProgress.currentLegProgress.currentStepProgress)
        instructionsBannerView?.isHidden = false
        
        // Update the user puck
        _mapView?.updateCourseTracking(location: location, animated: true)
    }
    
    //==========================================================
    // Update instruction banner
    //==========================================================
    @objc private func _updateInstructionsBanner(notification: NSNotification) {
        guard let routeProgress = notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey] as? RouteProgress else { return }
        _updateRouteProgress(routeProgress)
    }

    //==========================================================
    // Update route progress
    //==========================================================
    private func _updateRouteProgress(_ routeProgress : RouteProgress) {
        instructionsBannerView?.update(for: routeProgress.currentLegProgress.currentStepProgress.currentVisualInstruction)
        
        if let instruction = routeProgress.currentLegProgress.currentStepProgress.currentSpokenInstruction?.text {
            DispatchQueue.main.asyncAfter(deadline: .now()+1.0, execute: {
                sys.speech.speak(instruction)
            })
        }
        
    }
    
    //==========================================================
    // Fired when the user is no longer on the route.
    // Update the route on the map.
    //==========================================================
    @objc private func _rerouted(_ notification: NSNotification) {
        _mapView?.showRoutes([_navigationService.route])
    }

    
    //==========================================================
    // Toggle step list shown
    //==========================================================
    func addPreviewInstructions(step: RouteStep) {
        let route = _navigationService.route
        
        // find the leg that contains the step, legIndex, and stepIndex
        guard let leg       = route.legs.first(where: { $0.steps.contains(step) }),
            let legIndex  = route.legs.firstIndex(of: leg),
            let stepIndex = leg.steps.firstIndex(of: step) else {
            return
        }
        
        // find the upcoming manuever step, and update instructions banner to show preview
        guard stepIndex + 1 < leg.steps.endIndex else { return }
        let maneuverStep = leg.steps[stepIndex + 1]
        updatePreviewBannerWith(step: step, maneuverStep: maneuverStep)
        
        // stop tracking user, and move camera to step location
        if let mapView = self._mapView {
            mapView.tracksUserCourse = false
            mapView.userTrackingMode = .none
            mapView.enableFrameByFrameCourseViewTracking(for: 1)
            mapView.setCenter(maneuverStep.maneuverLocation, zoomLevel: mapView.zoomLevel, direction: maneuverStep.initialHeading!, animated: true, completionHandler: nil)
            
            // add arrow to map for preview instruction
            mapView.addArrow(route: route, legIndex: legIndex, stepIndex: stepIndex + 1)
        }
    }
    
    //==========================================================
    // Add Preview Banner with step instructions
    //==========================================================
    func updatePreviewBannerWith(step: RouteStep, maneuverStep: RouteStep) {
        // remove preview banner if it exists
        removePreviewInstruction()
        
        // grab the last instruction for step
        guard let instructions = step.instructionsDisplayedAlongStep?.last else { return }
        
        // create a StepInstructionsView and display that over the current instructions banner
        if let instructionsBannerView = self.instructionsBannerView {
            let previewInstructionsView = StepInstructionsView(frame: instructionsBannerView.frame)
            previewInstructionsView.delegate = self
            previewInstructionsView.swipeable = true
            previewInstructionsView.backgroundColor = instructionsBannerView.backgroundColor
            previewInstructionsView.alpha = 0.5
            view?.addSubview(previewInstructionsView)
            
            // update instructions banner to show all information about this step
            previewInstructionsView.updateDistance(for: RouteStepProgress(step: step))
            previewInstructionsView.update(for: instructions)
            
            self._previewInstructionsView = previewInstructionsView
        }
    }
    
    //==========================================================
    // Renove Preview Banner
    //==========================================================
    func removePreviewInstruction() {
        guard let view = _previewInstructionsView else { return }
        view.removeFromSuperview()
        
         // reclaim the delegate, from the preview banner
        instructionsBannerView?.delegate = self
        
        // nil out both the view and index
        _previewInstructionsView = nil
        _previewStepIndex = nil
    }
    
    //==========================================================
    // Toggle step list shown
    //==========================================================
    func _toggleStepsList() {
        // remove the preview banner while viewing the steps list
        removePreviewInstruction()

        if let controller = _stepsViewController {
            controller.dismiss()
            _stepsViewController = nil
        } else {
            guard let service = _navigationService else { return }
            
            let controller = StepsViewController(routeProgress: service.routeProgress)
            controller.delegate = self
            containerViewController?.addChild(controller)
            view?.addSubview(controller.view)
            
            if let instructionsBannerView = self.instructionsBannerView, let view = self.view {
                controller.view.topAnchor.constraint(equalTo: instructionsBannerView.bottomAnchor).isActive = true
                controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
                controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
                
                controller.didMove(toParent: containerViewController)
                
                _stepsViewController = controller
            }
            return
        }
    }
}


//--------------------------------------------------------------
// MARK: - extension TBTNavigator : MGLMapViewDelegate
//--------------------------------------------------------------
extension TBTNavigator : MGLMapViewDelegate {
    
    //==========================================================
    // viewDidLoad
    //==========================================================
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        self._mapView?.showRoutes([_navigationService.route])
    }
}

//--------------------------------------------------------------
// MARK: - extension TBTNavigator : MGLMapViewDelegate
//--------------------------------------------------------------
extension TBTNavigator: StepsViewControllerDelegate {
    
    //==========================================================
    // Dismiss step controller
    //==========================================================
    func didDismissStepsViewController(_ viewController: StepsViewController) {
        viewController.dismiss { [weak self] in
            self?._stepsViewController = nil
        }
    }
    
    //==========================================================
    //  Step selected
    //==========================================================
    func stepsViewController(_ viewController: StepsViewController, didSelect legIndex: Int, stepIndex: Int, cell: StepTableViewCell) {
        viewController.dismiss { [weak self] in
            self?._stepsViewController = nil
        }
    }
}


//--------------------------------------------------------------
// MARK: - extension TBTNavigator : InstructionsBannerViewDelegate
//--------------------------------------------------------------
extension TBTNavigator: InstructionsBannerViewDelegate {
    
    //==========================================================
    // Tapped instruction banner
    //==========================================================
    func didTapInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        _toggleStepsList()
    }
    
    //==========================================================
    // Swiped instruction banner
    //==========================================================
    func didSwipeInstructionsBanner(_ sender: BaseInstructionsBannerView, swipeDirection direction: UISwipeGestureRecognizer.Direction) {
        if direction == .down {
            _toggleStepsList()
            return
        }
        
        // preventing swiping if the steps list is visible
        guard _stepsViewController == nil else { return }
        
        // Make sure that we actually have remaining steps left
        guard let remainingSteps = _navigationService?.routeProgress.remainingSteps else { return }
        
        var previewIndex = -1
        var previewStep: RouteStep?
        
        if direction == .left {
            // get the next step from our current preview step index
            if let currentPreviewIndex = _previewStepIndex {
                previewIndex = currentPreviewIndex + 1
            } else {
                previewIndex = 0
            }
            
            // index is out of bounds, we have no step to show
            guard previewIndex < remainingSteps.count else { return }
            previewStep = remainingSteps[previewIndex]
        } else {
            // we are already at step 0, no need to show anything
            guard let currentPreviewIndex = _previewStepIndex else { return }
            
            if currentPreviewIndex > 0 {
                previewIndex = currentPreviewIndex - 1
                previewStep = remainingSteps[previewIndex]
            } else {
                previewStep = _navigationService.routeProgress.currentLegProgress.currentStep
                previewIndex = -1
            }
        }
        
        if let step = previewStep {
            addPreviewInstructions(step: step)
            _previewStepIndex = previewIndex
        }
    }
}
