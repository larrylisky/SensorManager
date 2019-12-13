//
//  sensorManager.swift
//  Dashphone
//
//  Created by Larry Li on 7/5/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import CoreLocation
import CoreMotion

class SensorManager : NSObject {

    // Sensor data structure
    struct SensorData : Codable {
        var longitude : Double = 0.0
        var latitude : Double = 0.0
        var accelX : Double = 0.0
        var accelY : Double = 0.0
        var accelZ : Double = 0.0
        var rotRateX : Double = 0.0
        var rotRateY : Double = 0.0
        var rotRateZ : Double = 0.0
        var gravityX : Double = 0.0      // current gravity vector relative to device reference frame
        var gravityY : Double = 0.0
        var gravityZ : Double = 0.0
        var roll : Double = 0.0          // roll pitch yaw are relative to magnitude north pole
        var pitch : Double = 0.0
        var yaw : Double = 0.0
        var speed : Double = 0.0
        var heading : Double = 0.0
        var course : Double = 0.0
        var altitude : Double = 0.0
        var horizontalAccuracy : Double = 0.0
        var verticalAccuracy : Double = 0.0
        var floor : Double = 0.0
    }

    var rotationMatrix : CMRotationMatrix = CMRotationMatrix()
    var quaternion : CMQuaternion = CMQuaternion()
    
    let motionManager = CMMotionManager()
    let locationManager = CLLocationManager()

    var shouldUseLocationServices : Bool = false
    var currentLocation: CLLocation?
    var currentHeading: CLHeading?
    var sensorUpdateInterval: Double = 0.05
    var data = SensorData()
    
    
    //==========================================================
    // Constructor
    //==========================================================
    override init() {
        super.init()
        requestAuthorization()
    }
    
    //==========================================================
    // Constructor
    //==========================================================
    func requestAuthorization() {
        enableLocationServices()
    }
    
    //==========================================================
    // Attach a UIView to display the map
    //==========================================================
    func enableLocationServices() {
        locationManager.delegate = self

        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            // Request when-in-use authorization initially
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted, .denied:
            break
        case .authorizedWhenInUse:
            break
        case .authorizedAlways:
            break
        default:
            break
        }
    }
    
    //==========================================================
    // Encode SensorData into JSON string
    //==========================================================
    open func jsonEncode(_ data: SensorData) -> String {
        let jsonData = try! JSONEncoder().encode(data)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
    
    //==========================================================
    // Decode a JSON string into a SensorData
    //==========================================================
    open func jsonDecode(_ string : String) -> SensorData? {
        if let jsonData = string.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                let report = try decoder.decode(SensorData.self, from: jsonData)
                return report
            }
            catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    //==========================================================
    // Collect device motion data
    //==========================================================
    @objc private func periodic() {
        _sensorUpdate()
    }
    
    
    //==========================================================
    // startMonitoringLocation
    //==========================================================
    func startMonitoring() {
        locationManager.startUpdatingLocation()
      //  locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingHeading()
        motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical)
    }
    
    //==========================================================
    // stopMonitoringLocation
    //==========================================================
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
    //    locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
    }
    
    //==========================================================
    // Collect device motion data
    //==========================================================
    private func _sensorUpdate() {
         if motionManager.isDeviceMotionAvailable && motionManager.isDeviceMotionActive {
            if let device = motionManager.deviceMotion {
                data.roll = device.attitude.roll
                data.pitch = device.attitude.pitch
                data.yaw = device.attitude.yaw
                data.gravityX = device.gravity.x
                data.gravityY = device.gravity.y
                data.gravityZ = device.gravity.z
                data.rotRateX = device.rotationRate.x
                data.rotRateY = device.rotationRate.y
                data.rotRateZ = device.rotationRate.z
                let accelX = device.userAcceleration.x
                let accelY = device.userAcceleration.y
                let accelZ = device.userAcceleration.z
                data.accelX = accelX
                data.accelY = accelY
                data.accelZ = accelZ
                rotationMatrix = device.attitude.rotationMatrix
                quaternion = device.attitude.quaternion
            }
        }
    }
    
}

//---------------------------------------------------------------
// Collection location related data
//---------------------------------------------------------------
extension SensorManager : CLLocationManagerDelegate {
    
    //==========================================================
    // Handle when authorization status changed
    //==========================================================
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways, .authorizedWhenInUse:
                shouldUseLocationServices = true
                locationManager.delegate = self
              //  locationManager.distanceFilter = kCLDistanceFilterNone
              //  locationManager.headingFilter = 5.0
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
              //  locationManager.allowsBackgroundLocationUpdates = true
              //  locationManager.pausesLocationUpdatesAutomatically = false
                motionManager.deviceMotionUpdateInterval = sensorUpdateInterval
                motionManager.accelerometerUpdateInterval = 0.005
                startMonitoring()
                Timer.scheduledTimer(timeInterval: sensorUpdateInterval, target: self, selector: #selector(self.periodic), userInfo: nil, repeats: true)
            default:
                stopMonitoring()
                shouldUseLocationServices = false
            }
        }
    }
    
    //==========================================================
    // Update location
    //==========================================================
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = manager.location {
            currentLocation = location
            data.longitude = location.coordinate.longitude
            data.latitude = location.coordinate.latitude
            data.speed = location.speed
            data.course = location.course
            data.altitude = location.altitude
            data.horizontalAccuracy = location.horizontalAccuracy
            data.verticalAccuracy = location.verticalAccuracy
            if let floor = location.floor {
                data.floor = Double(floor.level)
            }
        }
        if let heading: CLHeading = manager.heading  {
            currentHeading = heading
            data.heading = heading.trueHeading
        }
    }
}
