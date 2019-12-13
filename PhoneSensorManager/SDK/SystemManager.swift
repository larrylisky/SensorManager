//
//  SystemManager.swift
//  Dashphone
//
//  Created by Larry Li on 8/10/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import AVFoundation
import UIKit
import CoreMotion
import UserNotifications
import CoreLocation


class SystemManager : NSObject {

    var settings: SettingsManager!
    var profile: ProfileManager!
    var calendar: CalendarManager!
    var iot: IoTManager!
    var camera: CameraManager!
    var speech: SpeechManager!
    var map: MapManager!
    var sensor: SensorManager!
    var command: CommandDispatch!
    var storage: StorageManager!
    
    
    var deviceOrientation : UIDeviceOrientation {
        get {
            return UIDevice.current.orientation
        }
    }

    var userPool : [String : (Double, Double, Double, Int)] = [:]    // [ userId, (latitude, longitude, heading) ]
    
    private var _logPath : URL?
    var recordModules : [String] = []
    
    //=======================================================================
    // Constructor
    //=======================================================================
    override init() {
        super.init()
        
        storage = StorageManager()
        _initLogging()
        recordModules = ["CameraManager"]

        sensor = SensorManager()
        settings = SettingsManager()
        profile = ProfileManager()
        calendar = CalendarManager()
        iot = IoTManager(id: "")
        camera = CameraManager()
        speech = SpeechManager(name: settings.agentName)
        command = CommandDispatch()
        map = MapManager()
        storage = StorageManager()
    }
    
    //=======================================================================
    // System about to enter background
    //=======================================================================
    func enteringBackground() {
        _ = sys.speech.stopSpeaking()
        sys.speech.stopRecognition {}
        sys.camera.stopCaptureSession()
    }
    
    //=======================================================================
    // System entered background
    //=======================================================================
    func enteredBackground() {
 
    }
    
    //=======================================================================
    // System about to return to foreground
    //=======================================================================
    func enteringForeground() {
    }
    
    //=======================================================================
    // System about to return to foreground
    //=======================================================================
    func enteredForeground() {
        sys.camera.shouldCapturePhoto = true
        sys.camera.shouldCaptureMovie = true
        sys.camera.shouldSupportADAS = false
        sys.camera.desiredFPS = 30
        sys.camera.shouldSupportFaceDetection = false
        sys.camera.shouldSupportLandmarkDetection = false
        sys.camera.shouldSupportHeadPoseDetection = false
        sys.camera.videoStabilisationMode = .auto
        sys.camera.showAccessPermissionPopupAutomatically = true
        sys.camera.changeExposureMode(mode: .continuousAutoExposure)
        sys.camera.resumeCaptureSession()

        sys.speech.startRecognition()
    }
    
    //=======================================================================
    // System shutdown
    //=======================================================================
    func shutdown() {
        sys.camera.stopCaptureSession()
        _ = sys.speech.stopSpeaking()
        sys.speech.stopRecognition {}
    }
    
    //=======================================================================
    // Show modal alert on current top ViewController
    //=======================================================================
    func nearbyUsers() -> [CustomPointAnnotation] {
        var cars : [CustomPointAnnotation] = []
        if let id = sys.iot.id {
            sys.log("SystemManager", text: "Found \(userPool.count) nearby users\n")
            for user in userPool {
                if user.key != id {
                    let (latitude, longitude, heading, fresh) = user.value
                    if fresh > 0 {
                        sys.log("SystemManager", text: "User \(user.key) car icon to be displayed\n")

                        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let car = CustomPointAnnotation(coordinate: coord, title: user.key, subtitle: "Toyota" + "/" + "Camery")
                        car.image = UIImage(named: "hdCar")
                        car.heading = heading  // in degree
                        car.reuseIdentifier = user.key
                        cars.append(car)
                        userPool[user.key] = (latitude, longitude, heading, fresh-1)
                    }
                    else {
                        sys.log("SystemManager", text: "User \(user.key) car icon to deactivated\n")
                    }
                }
            }
        }
        return cars
    }
    
    
    //=======================================================================
    // Show modal alert on current top ViewController
    //=======================================================================
    func showAlert(title: String, message: String, prompt: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: prompt, style: .default, handler: nil)
        alertController.addAction(action)
        
        if let topMostViewController = UIApplication.shared.topMostViewController() {
            topMostViewController.present(alertController, animated: true, completion:  nil)
        }
    }
       
    //==========================================================
    // Show action sheet to get user confirmation
    //==========================================================
    func showActionSheet(title: String, message: String, actions: [UIAlertAction]) {
        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        actions.forEach(actionSheet.addAction(_:))
        
        if let topMostViewController = UIApplication.shared.topMostViewController() {
            topMostViewController.present(actionSheet, animated: true, completion: nil)
        }
    }
    
    //==========================================================
    // Log a string
    //==========================================================
    func log(_ module: String, text : String) {
        
        if recordModules.contains("all") || recordModules.contains(module) {
            if let path = _logPath {
                _ = storage.writeFile(fileURL: path, text: "\(module):\(String(format: "%.6f", CACurrentMediaTime())):\(text)")
                #if DEBUG
                print("\(module):\(String(format: "%.6f", CACurrentMediaTime())):\(text)")
                #endif
            }
        }
        
    }

    //==========================================================
    //  Play system sound
    //      Photo Shutter       - 1108
    //      Begin recording     - 1113
    //      End recording       - 1114
    //      Tock (flip)         - 1306
    //==========================================================
    func playSystemSound(_ id: Int) {
        if #available(iOS 9.0, *) {
            AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(id), nil)
        }
        else {
            AudioServicesPlaySystemSound(SystemSoundID(id))
        }
    }
    
    //==========================================================
    // Constructor
    //==========================================================
    private func _initLogging() {
        _logPath = storage.createFile(name: "systemLog.txt")
        if let path = _logPath {
            if storage.removeItem(at: path) == false {
                #if DEBUG
                print("Failed to remove logfile")
                #endif
            }
        }
        _logPath = storage.createFile(name: "systemLog.txt")
    }
    
}


////////////////////////////////////////////////////////////////////////////////
//  System Manager - extensions
////////////////////////////////////////////////////////////////////////////////
extension SystemManager {
    var versionNumber : String {
        get { return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String }
    }
    var buildNumber : String {
        get { return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String }
    }
}
