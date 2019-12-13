//
//  Broadcaster.swift
//  Dashphone
//
//  Created by Larry Li on 7/3/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import Foundation
import AVFoundation
import VideoToolbox
import LFLiveKit


///////////////////////////////////////////////////////////////////////////////
// BroadcasterDelegate
///////////////////////////////////////////////////////////////////////////////
protocol BroadcasterDelegate : NSObjectProtocol {
    func broadcaster(broadcaster: Broadcaster, debugInfo: LFLiveDebug?)
    func broadcaster(broadcaster: Broadcaster, errorCode: LFLiveSocketErrorCode)
    func broadcaster(broadcaster: Broadcaster, state: LFLiveState)
}


///////////////////////////////////////////////////////////////////////////////
// Broadcaster
///////////////////////////////////////////////////////////////////////////////
class Broadcaster : NSObject {
    
    weak var delegate : BroadcasterDelegate?
    var endpoint : String = ""
    var cameraPosition: AVCaptureDevice.Position = .back
    var session: LFLiveSession!
    var videoConfiguration : LFLiveVideoConfiguration?
    var audioConfiguration : LFLiveAudioConfiguration?
    
    enum BroadcasterState {
        case ready, pending, start, error, stop, refresh
    }
    
    //==========================================================
    // Constructor
    //==========================================================
    init(_ orientation: UIInterfaceOrientation) {
        super.init()
        session = {
            audioConfiguration = LFLiveAudioConfiguration.defaultConfiguration(for: LFLiveAudioQuality.high)
            videoConfiguration = LFLiveVideoConfiguration.defaultConfiguration(for: LFLiveVideoQuality.high3)
            videoConfiguration?.autorotate = true
            videoConfiguration?.outputImageOrientation = orientation
            videoConfiguration?.refreshVideoSize()
            let session = LFLiveSession(audioConfiguration: audioConfiguration, videoConfiguration: videoConfiguration, captureType: LFLiveCaptureTypeMask.inputMaskAll)
            return session!
        }()
        session.delegate = self
        session.beautyFace = false
        session.captureDevicePosition = cameraPosition
        requestAccessForVideo()
        requestAccessForAudio()
    }
    
    //==========================================================
    // Set output orientation
    //==========================================================
    func setOutputOrientation(_ orientation: UIInterfaceOrientation) {
        if session.running {
            stopBroadcast()
            session = nil
            videoConfiguration?.outputImageOrientation = orientation
            videoConfiguration?.refreshVideoSize()
            if let lfsession = LFLiveSession(audioConfiguration: audioConfiguration, videoConfiguration: videoConfiguration, captureType: LFLiveCaptureTypeMask.inputMaskAll) {
                session = lfsession
                startBroadcast()
            }
        }
    }
    
    //==========================================================
    // Setup preview view for display
    //==========================================================
    func setPreview(preview: UIView) {
        session.preView = preview
    }
    
    //==========================================================
    // Set boardcast endpoint
    //==========================================================
    func setEndPointURL(_ endpoint: String) {
        let stream = LFLiveStreamInfo()
        stream.url = endpoint
        self.endpoint = endpoint
    }
    
    //==========================================================
    // Start broadcasting
    //==========================================================
    func startBroadcast() {
        let stream = LFLiveStreamInfo()
        stream.url = endpoint
        session.startLive(stream)
    }
    
    //==========================================================
    // Stop broadcasting
    //==========================================================
    func stopBroadcast() {
        session.stopLive()
    }
    
    //==========================================================
    // Push video
    //==========================================================
    func pushVideo(_ pixelBuffer: CVPixelBuffer?) {
        session.pushVideo(pixelBuffer)
    }
    
    //==========================================================
    // Push audio
    //==========================================================
    func pushAudio(_ audioData: Data?) {
        session.pushAudio(audioData)
    }
    
    //==========================================================
    // Check if session is running
    //==========================================================
    func isRunning() -> Bool {
        return session.running
    }
    
    //==========================================================
    // Requestion authorization
    //==========================================================
    func requestAuthorization() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted) -> Void in
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted) -> Void in
                DispatchQueue.main.async(execute: { () -> Void in
                })
            })
        })
    }
    
    //==========================================================
    // Privacy authorization for video
    //==========================================================
    private func requestAccessForVideo() -> Void {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video);
        switch status  {
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [weak self] (granted) in
                if(granted){
                    DispatchQueue.main.async {
                        self?.session.running = true
                    }
                }
            })
            break;
        case AVAuthorizationStatus.authorized:
            session.running = true;
            break;
        case AVAuthorizationStatus.denied: break
        case AVAuthorizationStatus.restricted:break;
        default:
            break;
        }
    }
    
    //==========================================================
    // Privacy authorization for audio
    //==========================================================
    private func requestAccessForAudio() -> Void {
        let status = AVCaptureDevice.authorizationStatus(for:AVMediaType.audio)
        switch status  {
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted) in
                
            })
            break;
        case AVAuthorizationStatus.authorized:
            break;
        case AVAuthorizationStatus.denied: break
        case AVAuthorizationStatus.restricted:break;
        default:
            break;
        }
    }
}


//--------------------------------------------------------------------
// MARK: - LFLiveSessionDelegate
//--------------------------------------------------------------------
extension Broadcaster : LFLiveSessionDelegate {
    func liveSession(_ session: LFLiveSession?, debugInfo: LFLiveDebug?) {
        self.delegate?.broadcaster(broadcaster: self, debugInfo: debugInfo)
    }
    
    func liveSession(_ session: LFLiveSession?, errorCode: LFLiveSocketErrorCode) {
        self.delegate?.broadcaster(broadcaster: self, errorCode: errorCode)
    }
    
    func liveSession(_ session: LFLiveSession?, liveStateDidChange state: LFLiveState) {
        self.delegate?.broadcaster(broadcaster: self, state: state)
    }
}
