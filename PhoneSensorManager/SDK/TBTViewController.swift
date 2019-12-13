//
//  TBTViewController.swift
//  Dashphone
//
//  Created by Larry Li on 8/10/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import Mapbox
import CoreLocation
import AVFoundation
import MapboxDirections
import Turf


class TBTViewController: UIViewController {

    @objc func canRotate() -> Void {}

    var dismissCallback : (() -> Void)?
    var navigator = TBTNavigator()

    
   
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var instructionsBannerView: InstructionsBannerView!
    
    
    //==========================================================
    // MARK: - onCancelPressed(_ sender: Any)
    //==========================================================
    @IBAction func onCancelPressed(_ sender: Any) {
        dismissCallback?()
    }
    
    //==========================================================
    // viewDidLoad
    //==========================================================
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigator.containerViewController = self
        navigator.view = self.view
        navigator.instructionsBannerView = self.instructionsBannerView
        navigator.attachMap(to: self.view)
        navigator.setup()
    }
    
    //==========================================================
    // viewWillAppear
    //==========================================================
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
 
        DayStyle().apply()
        
        let currentCameraState = sys.camera.currentCameraStatus()
        if currentCameraState == .ready {
            addCameraToView(cameraView: self.cameraView)
        }
        sys.camera.resumeCaptureSession()
    }
    
    //==========================================================
    // viewWillDisappear
    //==========================================================
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sys.camera.stopCaptureSession()
        dismissCallback?()
    }
    

    //==========================================================
    //  Add UIView to be cameraManager previewLayer
    //==========================================================
    private func addCameraToView(cameraView : UIView) {
        sys.camera.addPreviewLayerToView(cameraView)
        sys.camera.showErrorBlock = { [weak self] (erTitle: String, erMessage: String) -> Void in
            let alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alertAction) -> Void in  }))
            self?.present(alertController, animated: true, completion: nil)
        }
    }
    

    //==========================================================
    // Cancel button handler
    //==========================================================
    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //==========================================================
    // Recenter handler
    //==========================================================
    @IBAction func recenterMap(_ sender: Any) {
        navigator.recenterMap()
    }
    
}


