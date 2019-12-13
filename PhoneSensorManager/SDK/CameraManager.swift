//
//  CameraManager.swift
//  camera
//
//  Created by  on 10/10/14.
//  Copyright (c) 2014 Imaginary Cloud. All rights reserved.
//
//  Enhanced by Larry Li 7/19/2019
//  Copyright (c) 2019 E-Motion, Inc. All rights reserved.


import UIKit
import AVFoundation
import Photos
import PhotosUI
import ImageIO
import MobileCoreServices
import CoreLocation
import CoreMotion
import CoreMedia
import Vision



//////////////////////////////////////////////////////////////////////////////////////

protocol CameraManagerDelegate : class {
    func captured(_ image: UIImage)
    func dropped(_ count: UInt64)
    func found(_ didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}

//////////////////////////////////////////////////////////////////////////////////////
public enum CameraState {
    case ready, accessDenied, noDeviceFound, notDetermined
}

public enum CameraDevice {
    case front, back
}

public enum CameraOutputQuality: Int {
    case low, medium, high
}


//////////////////////////////////////////////////////////////////////////////////////
///
///   CameraManager class
///
//////////////////////////////////////////////////////////////////////////////////////
class CameraManager : NSObject, UIGestureRecognizerDelegate {
    
    //==========================================================================
    //  Public variables
    //==========================================================================
    
    // CameraManagerDelegate
    open var delegate : CameraManagerDelegate?

    // Desired FPS : not guaranteed
    open var desiredFPS : Int32 = 30

    // Property for capture session to customize camera settings.
    open var captureSession: AVCaptureSession?
    
    // Should show the error for the user?
    open var showErrorsToUsers = false
    
    // Should support face detection
    open var shouldSupportFaceDetection = false
    
    // Given driver's face, find landmarks
    open var shouldSupportLandmarkDetection = false
    
    // Given driver's landmarks, find head pose
    open var shouldSupportHeadPoseDetection = false
    
    // Should capture movie
    open var shouldCaptureMovie = true
    
    // Should capture image
    open var shouldCapturePhoto = true
    
    // Indicating whether camera is streaming
    open var isStreaming = false
    
    // Captured image
    open var capturedPhoto : UIImage?
    
    // Should perform ADAS
    open var shouldSupportADAS = false
    
    // Enable or disable flip animation when switch between back and front camera.
    open var animateCameraDeviceChange: Bool = true
    
    // Determine if manager should keep view with the same bounds when the orientation changes.
    open var shouldKeepViewAtOrientationChanges = false
    
    // Property to set video stabilisation mode during a video record session
    open var videoStabilisationMode : AVCaptureVideoStabilizationMode = .auto
    
    // show the camera permission popup immediatly
    open var showAccessPermissionPopupAutomatically = true
    
    // frames per second
    open var measuredFPS : Double = 0

    // Enable or disable location services. Location services in camera is used for EXIF data.
    open var shouldUseLocationServices: Bool = false {
        didSet {
            if shouldUseLocationServices {
                self._locationManager = CameraLocationManager()
            }
        }
    }
    
    // Get the preview layer
    open var previewLayer: AVCaptureVideoPreviewLayer? {
        get {
            return _previewLayer
        }
    }
    
    // Property to change camera device between front and back.
    open var cameraDevice = CameraDevice.back {
        didSet {
            if _cameraIsSetup && cameraDevice != oldValue {
                if animateCameraDeviceChange {
                    _doFlipAnimation()
                }
                _updateCameraDevice(cameraDevice)
                _setupMaxZoomScale()
                _zoom(0)
                _orientationChanged()
            }
        }
    }
    
    // Property to change camera output quality.
    open var cameraOutputQuality = CameraOutputQuality.high {
        didSet {
            if _cameraIsSetup && cameraOutputQuality != oldValue {
                _updateCameraQualityMode(cameraOutputQuality)
            }
        }
    }
    
    // Determine if device has front camera
    open var hasFrontCamera: Bool = {
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
            return true
        }
        return false
    }()
    
    
    // Determine if manager should follow device orientation.
    open var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                _startFollowingDeviceOrientation()
            } else {
                _stopFollowingDeviceOrientation()
            }
        }
    }
    
    // Property to determine if current device has flash.
    open var hasFlash: Bool = {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified)
        let hasFlashDevices = discoverySession.devices.filter { $0.hasFlash }
        return !hasFlashDevices.isEmpty
    }()
    
    //==========================================================================
    //  Private variables
    //==========================================================================
    private var _context = CIContext()
    private var _droppedFrames : UInt64 = 0
    private var _coreMotionManager: CMMotionManager!
    private var _locationManager: CameraLocationManager?
    private var _cameraIsSetup = false
    private var _frameOutput: AVCaptureVideoDataOutput?
    private var _audioOutput: AVCaptureAudioDataOutput?
    private var _zoomScale       = CGFloat(1.0)
    private var _beginZoomScale  = CGFloat(1.0)
    private var _maxZoomScale    = CGFloat(1.0)
    private var _previewLayer: AVCaptureVideoPreviewLayer?
    private var _deviceOrientation: UIDeviceOrientation = .portrait
    private var _cameraIsObservingDeviceOrientation = false
    private var _transitionAnimating = false
    private var _cameraTransitionView: UIView?
    private let _sessionQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
    private let _faceQueue = DispatchQueue(label: "ai.dashphone", attributes: [])

    private var _videoCompletion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?
    
    private var _isRecording : Bool = false
    private var _videoWriter: AVAssetWriter!
    private var _videoWriterInput: AVAssetWriterInput!
    private var _audioWriterInput: AVAssetWriterInput!
    private var _sessionAtSourceTime: CMTime?
    
    private var _audioBufferList = AudioBufferList()
    private var _audioData = Data()
    private var _blockBuffer : CMBlockBuffer?
    
    private var _streamer : Broadcaster?
    
    private weak var _embeddingView: UIView?

    private lazy var _frontCameraDevice: AVCaptureDevice? = {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front).devices.first
    }()
    
    private lazy var _backCameraDevice: AVCaptureDevice? = {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back).devices.first
    }()
    
    private lazy var _mic: AVCaptureDevice? = {
        return AVCaptureDevice.default(for: AVMediaType.audio)
    }()


    // ADAS parameters
    private var _currentMetadata: [AnyObject] = []
    /*
    private let _dlib = DlibWrapper()
    private var _commandQueue: MTLCommandQueue!
    private var _textureCache: CVMetalTextureCache?
    private var _currentMetadata: [AnyObject] = []
    private var _lastTimestamp = CMTime()
    private let _layer = AVSampleBufferDisplayLayer()
    */
    private var _startTime : Double = 0.0
    private var _frameCount : Double = 0
    
    //==========================================================================
    //  Constructor
    //==========================================================================
    override init() {
        super.init()
        requestAuthorization()
    }

    
    //==========================================================================
    //  Starts streaming to endpoint
    //==========================================================================
    open func startStreaming(_ endpoint: String) {
       // stopCaptureSession()
        var orientation: UIInterfaceOrientation
        switch currentOrientation() {
            case .landscapeRight:
                orientation = .landscapeRight
            case .landscapeLeft:
                orientation = .landscapeLeft
            default:
                orientation = .portrait
        }
        _streamer = Broadcaster(orientation)
        _streamer?.setEndPointURL(endpoint)
        _streamer?.startBroadcast()
        isStreaming = true
    }
    
    //==========================================================================
    //  Starts streaming to endpoint
    //==========================================================================
    func stopStreaming() {
        isStreaming = false
        _streamer?.stopBroadcast()
        _streamer = nil
      //  resumeCaptureSession()
    }
    
    //==========================================================================
    //  Starts recording a video with or without voice as in the session preset.
    //==========================================================================
    open func startRecordingVideo() {
        guard !_isRecording else { return }
        _isRecording = true
        _sessionAtSourceTime = nil
        _setupWriter()
    }
    
    //==========================================================================
    //  Stop recording a video. Save it to the cameraRoll and give back the url.
    //==========================================================================
    open func stopVideoRecording(_ completion: ((_ asset: AVURLAsset?, _ error: NSError?) -> Void)? ) {
        guard _isRecording else { return }
        _isRecording = false
        _videoWriter.finishWriting { [weak self] in
            self?._sessionAtSourceTime = nil
            if let url = self?._videoWriter.outputURL {
                let asset = AVURLAsset(url: url)
                // Call caller-supplied completion handler to handle the video asset
                if let completion = completion {
                    completion(asset, nil)
                }
            }
            else {
                return
            }
        }
    }
    
    //==========================================================================
    //  Pause video recording
    //==========================================================================
    open func pauseVideoRecording() {
        _isRecording = false
    }
    
    //==========================================================================
    //  Resume video recording
    //==========================================================================
    open func resumeVideoRecording() {
        _isRecording = true
    }
    
    
    //==========================================================================
    //  Return true if cameraManager is currently recording video
    //==========================================================================
    open func isRecordingVideo() -> Bool {
        return _isRecording
    }
    
    
    //==========================================================================
    //  Return current device orientation
    //==========================================================================
    open func currentOrientation() -> UIDeviceOrientation {
        return currentPreviewDeviceOrientation()
    }
    
    
    //==========================================================================
    //  Permission
    //==========================================================================
    func requestAuthorization() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted) -> Void in
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted) -> Void in
                DispatchQueue.main.async(execute: { () -> Void in
                })
            })
        })
    }
    
    //==========================================================================
    //  Resume capture session
    //==========================================================================
    open func resumeCaptureSession() {
        sys.log("CameraManager", text: "resumeCaptureSession\n")

        _startTime = CACurrentMediaTime()
        _frameCount = 0.0
        
        if let validCaptureSession = captureSession {
            if !validCaptureSession.isRunning && _cameraIsSetup {
                validCaptureSession.startRunning()
                _startFollowingDeviceOrientation()
            }
        }
        else {
            if _canLoadCamera() {
                if _cameraIsSetup {
                    stopAndRemoveCaptureSession()
                }
                _setupCamera {
                    if let validEmbeddingView = self._embeddingView {
                        self._addPreviewLayerToView(validEmbeddingView)
                    }
                    self._startFollowingDeviceOrientation()
                }
            }
        }
    }
    
    //==========================================================================
    //   Stops running capture session but all setup devices, inputs and
    //   outputs stay for further reuse.
    //==========================================================================
    open func stopCaptureSession() {
        sys.log("CameraManager", text: "stopCaptureSession\n")
        if let session = captureSession, session.isRunning {
            captureSession?.stopRunning()
            _stopFollowingDeviceOrientation()
        }
    }
    
    //==========================================================================
    //  Stops running capture session and removes all setup devices,
    //  inputs and outputs.
    //==========================================================================
    open func stopAndRemoveCaptureSession() {
        self.stopCaptureSession()
        let oldAnimationValue = self.animateCameraDeviceChange
        self.animateCameraDeviceChange = false
        self.cameraDevice = .back
        self._cameraIsSetup = false
        self._previewLayer = nil
        self.captureSession = nil
        self._frontCameraDevice = nil
        self._backCameraDevice = nil
        self._mic = nil
        self._frameOutput = nil
        self._audioOutput = nil
        self.animateCameraDeviceChange = oldAnimationValue
    }

    //==========================================================================
    //  Inits a capture session and adds a preview layer to the given view.
    //  Preview layer bounds will automaticaly be set to match given view.
    //  Default session is initialized with still image output.
    //
    //  :param: view The view you want to add the preview layer to
    //  :param: cameraOutputMode The mode you want capturesession to run
    //              image / video / video and microphone
    //  :param: completion Optional completion block
    //
    //  :returns: Current state of the camera: Ready / AccessDenied
    //            / NoDeviceFound / NotDetermined.
    //==========================================================================
    @discardableResult open func addPreviewLayerToView(_ view: UIView) -> CameraState {
        return addLayerPreviewToView(view, completion: nil)
    }
    
    //==========================================================================
    // Add preview layer
    //==========================================================================
    @discardableResult open func addLayerPreviewToView(_ view: UIView, completion: (() -> Void)?) -> CameraState {
        if _canLoadCamera() {
            if let _ = _embeddingView {
                if let validPreviewLayer = _previewLayer {
                    validPreviewLayer.removeFromSuperlayer()
                }
            }
            if _cameraIsSetup {
                _addPreviewLayerToView(view)
                if let validCompletion = completion {
                    validCompletion()
                }
            } else {
                _setupCamera {
                    self._addPreviewLayerToView(view)
                    if let validCompletion = completion {
                        validCompletion()
                    }
                }
            }
        }
        return _checkIfCameraIsAvailable()
    }
    
    
    //==========================================================================
    //  Return current state of the camera: Ready / AccessDenied
    //                        / NoDeviceFound / NotDetermined
    //==========================================================================
    open func currentCameraStatus() -> CameraState {
        return _checkIfCameraIsAvailable()
    }
    
    //==========================================================================
    //  Zoom to the requested scale
    //==========================================================================
    open func zoom(_ scale: CGFloat) {
        _zoom(scale)
    }
    
    //==========================================================================
    // Change exposure mode. Available mode:
    // .Locked .AutoExpose .ContinuousAutoExposure .Custom
    //==========================================================================
    open func changeExposureMode(mode: AVCaptureDevice.ExposureMode) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = _backCameraDevice
        case .front:
            device = _frontCameraDevice
        }
        if (device?.exposureMode == mode) {
            return
        }
        
        do {
            try device?.lockForConfiguration()
        } catch {
            return
        }
        if device?.isExposureModeSupported(mode) == true {
            device?.exposureMode = mode
        }
        device?.unlockForConfiguration()
    }
    
    
    /////////////////////////////////////////////////////////////////////////////
    //   Private functions
    /////////////////////////////////////////////////////////////////////////////
    
    
    //==========================================================================
    //  Perform shutter animation
    //==========================================================================
    private func _performShutterAnimation(_ completion: (() -> Void)?) {
        
        if let validPreviewLayer = _previewLayer {
            
            DispatchQueue.main.async {
                
                let duration = 0.1
                
                CATransaction.begin()
                
                if let completion = completion {
                    CATransaction.setCompletionBlock(completion)
                }
                
                let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                fadeOutAnimation.fromValue = 1.0
                fadeOutAnimation.toValue = 0.0
                validPreviewLayer.add(fadeOutAnimation, forKey: "opacity")
                
                let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                fadeInAnimation.fromValue = 0.0
                fadeInAnimation.toValue = 1.0
                fadeInAnimation.beginTime = CACurrentMediaTime() + duration * 2.0
                validPreviewLayer.add(fadeInAnimation, forKey: "opacity")
                
                CATransaction.commit()
            }
        }
    }
    
    //==========================================================================
    //  Setup output mode
    //==========================================================================
    private func _setupCamera(_ completion: @escaping () -> Void) {
        sys.log("CameraManager", text: "_setupCamera\n")

        captureSession = AVCaptureSession()
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker] )
            try audioSession.setActive(true)
            sys.log("CameraManager", text: "audio session activated\n")

        }
        catch let error as NSError {
            sys.log("CameraManager", text: "unable to activate audio session; error=\(error.localizedDescription)\n")
        }
        
        _sessionQueue.async(execute: {
            if let validCaptureSession = self.captureSession {
                
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
                self._updateCameraDevice(self.cameraDevice)
                self._setupOutputs()
                self._setupOutputMode()
                self._setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                self._updateCameraQualityMode(self.cameraOutputQuality)
                validCaptureSession.startRunning()
                self._startFollowingDeviceOrientation()
                self._cameraIsSetup = true
                self._orientationChanged()
                
                DispatchQueue.main.async {
                    completion()
                }
            }
        }) // _sessionQueue
    }
    
    //==========================================================================
    //  Setup the preview layer
    //==========================================================================
    fileprivate func _setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            sys.log("CameraManager", text: "_setupPreviewLayer\n")

            _previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            _previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
    
    //==========================================================================
    //  Add preview layer to a given view
    //==========================================================================
    private func _addPreviewLayerToView(_ view: UIView) {
        sys.log("CameraManager", text: "_addPreviewLayerToView\n")
        _embeddingView = view
        DispatchQueue.main.async(execute: { () -> Void in
            guard let previewLayer = self._previewLayer else { return }
            previewLayer.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.insertSublayer(previewLayer, at: 0)
        })
    }
    
    //==========================================================================
    //  Setup output mode
    //==========================================================================
    private func _canLoadCamera() -> Bool {
        let currentCameraState = _checkIfCameraIsAvailable()
        return currentCameraState == .ready || (currentCameraState == .notDetermined && showAccessPermissionPopupAutomatically)
    }
    
    //==========================================================================
    //  Check if camera is available
    //==========================================================================
    private func _checkIfCameraIsAvailable() -> CameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                sys.log("CameraManager", text: "_checkIfCameraIsAvailable - access defined\n")
                _show(NSLocalizedString("Camera access denied", comment:""), message:NSLocalizedString("You need to go to settings app and grant acces to the camera device to use it.", comment:""))
                return .accessDenied
            }
        } else {
            sys.log("CameraManager", text: "_checkIfCameraIsAvailable - camera unavailable\n")
            _show(NSLocalizedString("Camera unavailable", comment:""), message:NSLocalizedString("The device does not have a camera.", comment:""))
            return .noDeviceFound
        }
    }
    
    //==========================================================================
    //  configure device
    //==========================================================================
    private func _configureDevice(_ captureDevice: AVCaptureDevice) {
        // Based on code from https://github.com/dokun1/Lumina/
        let activeDimensions = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        for vFormat in captureDevice.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            if let frameRate = ranges.first,
                frameRate.maxFrameRate >= Float64(desiredFPS) &&
                    frameRate.minFrameRate <= Float64(desiredFPS) &&
                    activeDimensions.width == dimensions.width &&
                    activeDimensions.height == dimensions.height &&
                    CMFormatDescriptionGetMediaSubType(vFormat.formatDescription) == 875704422 { // meant for full range 420f
                do {
                    sys.log("CameraManager", text: "_configureDevice lockForConfiguration - start\n")
                    try captureDevice.lockForConfiguration()
                    captureDevice.activeFormat = vFormat as AVCaptureDevice.Format
                    captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 10, timescale: Int32(desiredFPS*10))
                    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 10, timescale: Int32(desiredFPS*10))
                    captureDevice.unlockForConfiguration()
                    sys.log("CameraManager", text: "_configureDevice lockForConfiguration - end\n")
                    break
                } catch {
                    sys.log("CameraManager", text: "_configureDevice lockForConfiguration - failed\n")
                    continue
                }
            }
        }
    }
    
    
    //==========================================================================
    //  Setup output
    //==========================================================================
    fileprivate func _setupOutputs() {
        sys.log("CameraManager", text: "_setupOutputs\n")

        let queue = DispatchQueue(label: "sample buffer")
        
        if _frameOutput == nil {
            _frameOutput = AVCaptureVideoDataOutput()
            _frameOutput?.alwaysDiscardsLateVideoFrames = true
            if let frameOutput = _frameOutput {
                frameOutput.setSampleBufferDelegate(self, queue: queue)
            }
        }
        if _audioOutput == nil {
            _audioOutput = AVCaptureAudioDataOutput()
            if let audioOutput = _audioOutput {
                audioOutput.setSampleBufferDelegate(self, queue: queue)
            }
        }
    }
    
    //==========================================================================
    //  Setup output mode
    //==========================================================================
    private func _setupOutputMode() {
        
        sys.log("CameraManager", text: "_setupOutputMode\n")

        if let captureSession = captureSession {
            captureSession.beginConfiguration()
            let frameOutput = _getFrameOutput()
            if captureSession.canAddOutput(frameOutput) {
                captureSession.addOutput(frameOutput)
            }
            let audioOutput = _getAudioOutput()
            if captureSession.canAddOutput(audioOutput) {
                captureSession.addOutput(audioOutput)
            }
            captureSession.commitConfiguration()
            _updateCameraQualityMode(cameraOutputQuality)
            _orientationChanged()
        }
    }
    
    
    //==========================================================================
    //  Perform flip animation
    //==========================================================================
    private func _doFlipAnimation() {
        
        sys.log("CameraManager", text: "_doFlipAnimation\n")

        if _transitionAnimating {
            sys.log("CameraManager", text: "_doFlipAnimation found _transitionAnimating so returned\n")
            return
        }
        
        if let validEmbeddingView = _embeddingView,
            let validPreviewLayer = _previewLayer {
            var tempView = UIView()
            
            if CameraManager._blurSupported() {
                let blurEffect = UIBlurEffect(style: .light)
                tempView = UIVisualEffectView(effect: blurEffect)
                tempView.frame = validEmbeddingView.bounds
            } else {
                tempView = UIView(frame: validEmbeddingView.bounds)
                tempView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            }
            
            validEmbeddingView.insertSubview(tempView, at: Int(validPreviewLayer.zPosition + 1))
            
            _cameraTransitionView = validEmbeddingView.snapshotView(afterScreenUpdates: true)
            
            if let cameraTransitionView = _cameraTransitionView {
                validEmbeddingView.insertSubview(cameraTransitionView, at: Int(validEmbeddingView.layer.zPosition + 1))
            }
            tempView.removeFromSuperview()
            
            _transitionAnimating = true
            
            validPreviewLayer.opacity = 0.0
            
            DispatchQueue.main.async {
                self._flipCameraTransitionView()
            }
        }
    }
    
    //==========================================================================
    //  Update camera device
    //==========================================================================
    private func _updateCameraDevice(_ deviceType: CameraDevice) {
        if let validCaptureSession = captureSession {
            
            sys.log("CameraManager", text: "_updateCameraDevice beginConfiguration\n")

            validCaptureSession.beginConfiguration()
            
            
            let inputs: [AVCaptureInput] = validCaptureSession.inputs
            
            for input in inputs {
                //  if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device != _mic {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    sys.log("CameraManager", text: "_updateCameraDevice removing input device=\(deviceInput.device)\n")
                    validCaptureSession.removeInput(deviceInput)
                }
            }
            
            switch cameraDevice {
            case .front:
                if hasFrontCamera {
                    if let validFrontDevice = _deviceInputFromDevice(_frontCameraDevice),
                        !inputs.contains(validFrontDevice) {
                        sys.log("CameraManager", text: "_updateCameraDevice adding front camera\n")
                        validCaptureSession.addInput(validFrontDevice)
                        _configureDevice(_frontCameraDevice!)
                    }
                }
            case .back:
                if let validBackDevice = _deviceInputFromDevice(_backCameraDevice),
                    !inputs.contains(validBackDevice) {
                    sys.log("CameraManager", text: "_updateCameraDevice adding back camera\n")
                    validCaptureSession.addInput(validBackDevice)
                    _configureDevice(_backCameraDevice!)
                }
            }
            
            // Add microphone to your session
            if let validMicDevice = _deviceInputFromDevice(_mic),
                !inputs.contains(validMicDevice) {
                sys.log("CameraManager", text: "_updateCameraDevice adding mic\n")
                validCaptureSession.addInput(validMicDevice)
            }
            
            validCaptureSession.commitConfiguration()
            sys.log("CameraManager", text: "_updateCameraDevice committed Configuration\n")
        }
    }
    
    
    //==========================================================================
    //  Get AVCaptureDeviceInput
    //==========================================================================
    private func _deviceInputFromDevice(_ device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        }
        catch let outError {
            sys.log("CameraManager", text: "_deviceInputFromDevice error\n")
            _show(NSLocalizedString("Device setup error occured", comment:""), message: "\(outError)")
            return nil
        }
    }

    
    //==========================================================================
    //  Returns a valid instance of frameOutput, create if required
    //==========================================================================
    private func _getFrameOutput() -> AVCaptureVideoDataOutput {
        if _frameOutput == nil {
            let newFrameOutput = AVCaptureVideoDataOutput()
            newFrameOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            newFrameOutput.alwaysDiscardsLateVideoFrames = true
            _frameOutput = newFrameOutput
        }
        return _frameOutput!
    }
    
    //==========================================================================
    //  Returns a valid instance of audioOutput, create if required
    //==========================================================================
    private func _getAudioOutput() -> AVCaptureAudioDataOutput {
        if _audioOutput == nil {
            let newAudioOutput = AVCaptureAudioDataOutput()
            _audioOutput = newAudioOutput
        }
        return _audioOutput!
    }

    
    //==========================================================================
    //  Update camera quality mode
    //==========================================================================
    private func _updateCameraQualityMode(_ newCameraOutputQuality: CameraOutputQuality) {
        if let validCaptureSession = captureSession {
            var sessionPreset = AVCaptureSession.Preset.low
            switch newCameraOutputQuality {
            case CameraOutputQuality.low:
                sessionPreset = AVCaptureSession.Preset.low
            case CameraOutputQuality.medium:
                sessionPreset = AVCaptureSession.Preset.medium
            case CameraOutputQuality.high:
                sessionPreset = AVCaptureSession.Preset.hd1280x720   // was .high
            }
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            } else {
                sys.log("CameraManager", text: "Preset not supported error\n")
                _show(NSLocalizedString("Preset not supported", comment:""),
                      message: NSLocalizedString("Camera preset not supported. Please try another one.", comment:""))
            }
        } else {
            sys.log("CameraManager", text: "No valid capture session found; can't take picture or video.\n")
            _show(NSLocalizedString("Camera error", comment:""),
                  message: NSLocalizedString("No valid capture session found, I can't take any pictures or videos.", comment:""))
        }
    }
    
    //==========================================================================
    //  Return URL of temp file path
    //==========================================================================
    private func _tempFilePath() -> URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMovie\(Date().timeIntervalSince1970)").appendingPathExtension("mp4")
        return tempURL
    }
    
    //==========================================================================
    //  setup the video writer
    //==========================================================================
    private func _setupWriter() {
        do {
            let outputFileLocation = videoFileLocation()
            _videoWriter = try AVAssetWriter(outputURL: outputFileLocation, fileType: AVFileType.mp4)
            
            // add video input
            if #available(iOS 11.0, *) {
                if currentCaptureVideoOrientation() == .portrait ||
                    currentCaptureVideoOrientation() == .portraitUpsideDown {
                    _videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                        AVVideoCodecKey : AVVideoCodecType.h264,
                        AVVideoWidthKey : 720,
                        AVVideoHeightKey : 1280,
                        AVVideoCompressionPropertiesKey : [
                            AVVideoAverageBitRateKey : 2300000,
                        ],
                    ])
                }
                else {
                    _videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                        AVVideoCodecKey : AVVideoCodecType.h264,
                        AVVideoWidthKey : 1280,
                        AVVideoHeightKey : 720,
                        AVVideoCompressionPropertiesKey : [
                            AVVideoAverageBitRateKey : 2300000,
                        ],
                    ])
                }
            }
            else {
                // Fallback on earlier versions
                sys.log("CameraManager", text: "_setupWriter - need iOS 11.0 or higher\n")
                return
            }
            _videoWriterInput.expectsMediaDataInRealTime = true
            if _videoWriter.canAdd(_videoWriterInput) {
                _videoWriter.add(_videoWriterInput)
            }
            
            // add audio input
            _audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 64000,
                ])
            _audioWriterInput.expectsMediaDataInRealTime = true
            if _videoWriter.canAdd(_audioWriterInput) {
                _videoWriter.add(_audioWriterInput)
            }
    
            _videoWriter.startWriting()
        }
        catch let error {
            sys.log("CameraManager", text: "AVAssetWriter try failed with error=\(error.localizedDescription)\n")
        }
    }
    
    //==========================================================================
    //  setup the video writer
    //==========================================================================
    private func _canWrite() -> Bool {
        return _isRecording && _videoWriter != nil && _videoWriter?.status == .writing
    }
    
    
    
    //==========================================================================
    // video file location method
    //==========================================================================
    private func videoFileLocation() -> URL {
        let videoOutputUrl = _tempFilePath()
        if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
            do {
                try FileManager.default.removeItem(at: videoOutputUrl)
            }
            catch {
                print(error)
            }
        }
        return videoOutputUrl
    }
    
    
    //==========================================================================
    // Setup the maximium zoom scale
    //==========================================================================
    private func _setupMaxZoomScale() {
        var maxZoom = CGFloat(1.0)
        _beginZoomScale = CGFloat(1.0)
        
        if cameraDevice == .back, let backCameraDevice = _backCameraDevice  {
            maxZoom = backCameraDevice.activeFormat.videoMaxZoomFactor
        } else if cameraDevice == .front, let frontCameraDevice = _frontCameraDevice {
            maxZoom = frontCameraDevice.activeFormat.videoMaxZoomFactor
        }
        
        _maxZoomScale = maxZoom
    }
    
    //==========================================================================
    // Setup zoom factor
    //==========================================================================
    private func _zoom(_ scale: CGFloat) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
        case .back:
            device = _backCameraDevice
        case .front:
            device = _frontCameraDevice
        }
        
        do {
            let captureDevice = device
            sys.log("CameraManager:", text: "_zoom lockForConfiguration\n")
            try captureDevice?.lockForConfiguration()
            
            _zoomScale = max(1.0, min(_beginZoomScale * scale, _maxZoomScale))
            
            captureDevice?.videoZoomFactor = _zoomScale
            
            captureDevice?.unlockForConfiguration()
            sys.log("CameraManager:", text: "_zoom unLockForConfiguration\n")

        } catch {
            sys.log("CameraManager:", text: "Error locking zoom configuration\n")
        }
    }
    
    //==========================================================================
    //  Orientation changed
    //==========================================================================
    private func _startFollowingDeviceOrientation() {
        sys.log("CameraManager:", text: "_startFollowingDeviceOrientation\n")

        if shouldRespondToOrientationChanges && !_cameraIsObservingDeviceOrientation {
            _coreMotionManager = CMMotionManager()
            _coreMotionManager.accelerometerUpdateInterval = 0.005
            
            if _coreMotionManager.isAccelerometerAvailable {
                _coreMotionManager.startAccelerometerUpdates(to: OperationQueue(), withHandler:
                    {data, error in
                        
                        guard let acceleration: CMAcceleration = data?.acceleration  else{
                            return
                        }
                        
                        let scaling: CGFloat = CGFloat(1) / CGFloat(( abs(acceleration.x) + abs(acceleration.y)))
                        
                        let x: CGFloat = CGFloat(acceleration.x) * scaling
                        let y: CGFloat = CGFloat(acceleration.y) * scaling
                        
                        
                        if acceleration.z < Double(-0.75) {
                            self._deviceOrientation = .faceUp
                        } else if acceleration.z > Double(0.75) {
                            self._deviceOrientation = .faceDown
                        } else if x < CGFloat(-0.5) {
                            self._deviceOrientation = .landscapeLeft
                        } else if x > CGFloat(0.5) {
                            self._deviceOrientation = .landscapeRight
                        } else if y > CGFloat(0.5) {
                            self._deviceOrientation = .portraitUpsideDown
                        } else {
                            self._deviceOrientation = .portrait
                        }
                        
                        self._orientationChanged()
                })
                
                _cameraIsObservingDeviceOrientation = true
            } else {
                _cameraIsObservingDeviceOrientation = false
            }
        }
    }
    
    
    //==========================================================================
    //  Orientation changed
    //==========================================================================
    private func _stopFollowingDeviceOrientation() {
        sys.log("CameraManager:", text: "_stopFollowingDeviceOrientation\n")
        if _cameraIsObservingDeviceOrientation {
            _coreMotionManager.stopAccelerometerUpdates()
            _cameraIsObservingDeviceOrientation = false
        }
    }
    
    //==========================================================================
    //  Orientation changed
    //==========================================================================
    @objc private func _orientationChanged() {
        sys.log("CameraManager:", text: "_orientationChanged\n")
        let currentConnection = _getFrameOutput().connection(with: AVMediaType.video)
        
        if let validPreviewLayer = _previewLayer {
            if !shouldKeepViewAtOrientationChanges {
                if let validPreviewLayerConnection = validPreviewLayer.connection,
                    validPreviewLayerConnection.isVideoOrientationSupported {
                    validPreviewLayerConnection.videoOrientation = _currentPreviewVideoOrientation()
                }
            }
            if let validOutputLayerConnection = currentConnection,
                validOutputLayerConnection.isVideoOrientationSupported {
                
                validOutputLayerConnection.videoOrientation = currentCaptureVideoOrientation()
            }
            if !shouldKeepViewAtOrientationChanges && _cameraIsObservingDeviceOrientation {
                DispatchQueue.main.async(execute: { () -> Void in
                    if let validEmbeddingView = self._embeddingView {
                        validPreviewLayer.frame = validEmbeddingView.bounds
                    }
                })
            }
        }
    }
    
    //==========================================================================
    // Return current AVCapture orientation
    //==========================================================================
    func currentCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        if _deviceOrientation == .faceDown
            || _deviceOrientation == .faceUp
            || _deviceOrientation == .unknown {
            return _currentPreviewVideoOrientation()
        }
        return _videoOrientation(forDeviceOrientation: _deviceOrientation)
    }
    
    //==========================================================================
    // Return current preview device orientation
    //==========================================================================
    func currentPreviewDeviceOrientation() -> UIDeviceOrientation {
        if shouldKeepViewAtOrientationChanges {
            return .portrait
        }
        
        return UIDevice.current.orientation
    }
    
    //==========================================================================
    // Return correct AVCaptureVideoOrientation
    //==========================================================================
    private func _videoOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .faceUp:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face up
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face up
             */
            if let validPreviewLayer = _previewLayer, let connection = validPreviewLayer.connection  {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return _videoOrientationFromStatusBarOrientation()
        case .faceDown:
            /*
             Attempt to keep the existing orientation.  If the device was landscape, then face down
             getting the orientation from the stats bar would fail every other time forcing it
             to default to portrait which would introduce flicker into the preview layer.  This
             would not happen if it was in portrait then face down
             */
            if let validPreviewLayer = _previewLayer, let connection = validPreviewLayer.connection  {
                return connection.videoOrientation //Keep the existing orientation
            }
            //Could not get existing orientation, try to get it from stats bar
            return _videoOrientationFromStatusBarOrientation()
        default:
            return .portrait
        }
    }
    
    //==========================================================================
    // Determine orientation based on status bar
    //==========================================================================
    private func _videoOrientationFromStatusBarOrientation() -> AVCaptureVideoOrientation {
        
        var orientation: UIInterfaceOrientation?
        
        DispatchQueue.main.async {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        /*
         Note - the following would fall into the guard every other call (it is called repeatedly) if the device was
         landscape then face up/down.  Did not seem to fail if in portrait first.
         */
        guard let statusBarOrientation = orientation else {
            return .portrait
        }
        
        switch statusBarOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
    
    //==========================================================================
    // Return current preview video orientation
    //==========================================================================
    private func _currentPreviewVideoOrientation() -> AVCaptureVideoOrientation {
        let orientation = currentPreviewDeviceOrientation()
        return _videoOrientation(forDeviceOrientation: orientation)
    }
    
    //==========================================================================
    // Perform flip camera view transition
    //==========================================================================
    private func _flipCameraTransitionView() {
        
        if let cameraTransitionView = _cameraTransitionView {
            
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIView.AnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: { (_) -> Void in
                                self._removeCameraTransistionView()
            })
        }
    }
    
    //==========================================================================
    // Remove flip camera view transition
    //==========================================================================
    fileprivate func _removeCameraTransistionView() {
        
        if let cameraTransitionView = _cameraTransitionView {
            if let validPreviewLayer = _previewLayer {
                validPreviewLayer.opacity = 1.0
            }
            
            UIView.animate(withDuration: 0.5,
                           animations: { () -> Void in
                            
                            cameraTransitionView.alpha = 0.0
                            
            }, completion: { [weak self] (_) -> Void in
                
                self?._transitionAnimating = false
                
                cameraTransitionView.removeFromSuperview()
                self?._cameraTransitionView = nil
            })
        }
    }
       
    
    //==========================================================================
    // Show error to User
    //==========================================================================
    fileprivate func _show(_ title: String, message: String) {
        if showErrorsToUsers {
            DispatchQueue.main.async(execute: { () -> Void in
                self.showErrorBlock(title, message)
            })
        }
    }
    
    //==========================================================================
    // A block creating UI to present error message to the user. This can be
    // customised to be presented on the Window root view controller, or to pass
    // in the viewController which will present the UIAlertController,
    // for example.
    //==========================================================================
    open var showErrorBlock:(_ erTitle: String, _ erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        
        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alertAction) -> Void in  }))
        
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(alertController, animated: true, completion:nil)
        }
    }
    
    //==========================================================================
    // Return device name string
    //==========================================================================
    private class func _hardwareString() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        guard let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) else {
            return ""
        }
        return deviceName
    }
    
    //==========================================================================
    // Determining whether the current device actually supports blurring
    // As seen on: http://stackoverflow.com/a/29997626/2269387
    //==========================================================================
    private class func _blurSupported() -> Bool {
        var supported = Set<String>()
        supported.insert("iPad")
        supported.insert("iPad1,1")
        supported.insert("iPhone1,1")
        supported.insert("iPhone1,2")
        supported.insert("iPhone2,1")
        supported.insert("iPhone3,1")
        supported.insert("iPhone3,2")
        supported.insert("iPhone3,3")
        supported.insert("iPod1,1")
        supported.insert("iPod2,1")
        supported.insert("iPod2,2")
        supported.insert("iPod3,1")
        supported.insert("iPod4,1")
        supported.insert("iPad2,1")
        supported.insert("iPad2,2")
        supported.insert("iPad2,3")
        supported.insert("iPad2,4")
        supported.insert("iPad3,1")
        supported.insert("iPad3,2")
        supported.insert("iPad3,3")
        
        return !supported.contains(_hardwareString())
    }
    
    //==========================================================================
    // Image conversion
    //==========================================================================
    private func _imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = _context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    
    //==========================================================================
    // Completion
    //==========================================================================
    private func _executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
        if let validCompletion = _videoCompletion {
            validCompletion(url, error)
            _videoCompletion = nil
        }
    }
    
    //==========================================================================
    // CameraLocationManager
    //==========================================================================
    private class CameraLocationManager: NSObject, CLLocationManagerDelegate {
        var locationManager = CLLocationManager()
        var latestLocation: CLLocation?
        
        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.headingFilter = 5.0
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
        
        func startUpdatingLocation() {
            locationManager.startUpdatingLocation()
        }
        
        func stopUpdatingLocation() {
            locationManager.stopUpdatingLocation()
        }
        
        // MARK: - CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            // Pick the location with best (= smallest value) horizontal accuracy
            latestLocation = locations.sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }.first
        }
        
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.startUpdatingLocation()
            } else {
                locationManager.stopUpdatingLocation()
            }
        }
    }
    
    
    //================================================================
    //  ADAS update to be inserted into
    //  AVCaptureVideoDataOutputSampleBufferDelegate.captureOutput()
    //================================================================
    private func _updateADAS(_ output: AVCaptureOutput, connection: AVCaptureConnection, sampleBuffer : CMSampleBuffer) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.delegate?.found(imageBuffer, timestamp: timestamp)
        }
    }

    
    //==========================================================================
    //  addToVideoRecording - to be inserted into captureOutput delegate
    //==========================================================================
    private func _addToVideoRecording(_ output: AVCaptureOutput, sampleBuffer : CMSampleBuffer) {
        DispatchQueue.main.async { [unowned self] in
    
            if self._isRecording {
                let writable = self._canWrite()
            
                guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
                if writable, self._sessionAtSourceTime == nil {
                    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    self._sessionAtSourceTime = time
                    self._videoWriter.startSession(atSourceTime: time)
                }
                if output == self._frameOutput  {
                    if self._videoWriterInput.isReadyForMoreMediaData {
                        self._videoWriterInput.append(sampleBuffer)
                    }
                }
                else if output == self._audioOutput {
                    if self._audioWriterInput.isReadyForMoreMediaData {
                        self._audioWriterInput.append(sampleBuffer)
                    }
                }
            }
        } // DispatchQueue
    }
    
    //================================================================
    //  Add observers to handle interruption
    //================================================================
    private func _addObservers() {
        var SessionRunningContext = 0
        captureSession?.addObserver(self, forKeyPath: "running", options: NSKeyValueObservingOptions.new, context: &SessionRunningContext)
        
        NotificationCenter.default.addObserver(self, selector: #selector(_handleAVCaptureInterruption), name: .AVCaptureSessionWasInterrupted, object: captureSession)
        NotificationCenter.default.addObserver(self, selector: #selector(_handleAVCaptureInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: captureSession)
    }
    
    @objc private func _handleAVCaptureInterruption() {
    }
    
    @objc private func _handleAVCaptureInterruptionEnded() {
    }
}

///////////////////////////////////////////////////////////////////////////////
//  AVCaptureVideoDataOutputSampleBufferDelegate
///////////////////////////////////////////////////////////////////////////////
extension CameraManager : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    //==========================================================================
    //  Frame capture
    //==========================================================================
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        // Measure frame rate
        if output == self._frameOutput {
            _frameCount = _frameCount + 1
            let dt = CACurrentMediaTime() - _startTime
            measuredFPS = (dt > 0) ? Double(_frameCount) / dt : 0.0
        }
        
        // Handle streaming
        if let streamer = self._streamer, self.isStreaming && streamer.isRunning() {
            DispatchQueue.main.async {
                if output == self._frameOutput {
                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        streamer.pushVideo(imageBuffer)
                    }
                }
                else if output == self._audioOutput {
                    self._audioData = Data()
                    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: nil, bufferListOut: &self._audioBufferList, bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &self._blockBuffer)
                    
                    let buffers = UnsafeBufferPointer<AudioBuffer>(start: &self._audioBufferList.mBuffers, count: Int(self._audioBufferList.mNumberBuffers))
                    
                    for audioBuffer in buffers {
                        let frame = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self)
                        self._audioData.append(frame!, count: Int(audioBuffer.mDataByteSize))
                    }
                    streamer.pushAudio(self._audioData)
             //       self._audioData.removeAll()
                }
                
            } // DispatchQueue
        }
        
        // Handle video recording
        if self.shouldCaptureMovie {
            self._addToVideoRecording(output, sampleBuffer: sampleBuffer)
        }
        
        // Handle snapshot
        if self.shouldCapturePhoto {
            if let image = self._imageFromSampleBuffer(sampleBuffer: sampleBuffer) {
                self.delegate?.captured(image)
            }
        }
        
        // Handle ADAS/Face
        if self.shouldSupportADAS || self.shouldSupportFaceDetection {
            self._updateADAS(output, connection: connection, sampleBuffer: sampleBuffer)
        }
    }
    
    //==========================================================================
    //  Frame drop
    //==========================================================================
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        _droppedFrames += 1
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.dropped(self._droppedFrames)
        }
    }
    
}


