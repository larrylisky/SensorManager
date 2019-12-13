//
//  SoundMeter.swift
//  Dashphone
//
//  Created by Larry Li on 10/1/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import AVFoundation

class SoundMeter : NSObject {
    
    var alpha : Double = 0.05
    var ambientAlpha : Double = 0.005
    var onThresh : Double = 4.0   // dB
    var offThresh : Double = 2.0  // dB
    var offDuration : Double = 5.0 // seconds
    var timer : Timer?
    var isActive : Bool = false
    
    // MARK: - format status
    var formatOK : Bool {
        get {
            return _formatDesc != nil
        }
    }
    
    // MARK: - Bits per sample
    var bitsPersSample : UInt32 {
        get {
            return _formatDesc!.pointee.mBitsPerChannel
        }
    }
    
    // MARK: - Sample rate
    var sampleRate : Double {
        get {
            return _format.sampleRate
        }
    }
    
    // MARK: - Channel count
    var channelCount : Int {
        get {
            return Int(_format.channelCount)
        }
    }
    
    // MARK: - Bits per sample
    var bytesPerFrame : UInt32 {
        get {
            return _formatDesc!.pointee.mBytesPerFrame
        }
    }
    
    // MARK: - Bits per sample
    var isInterleaved : Bool {
        get {
            return _format.isInterleaved
        }
    }
    
    //---------------------------------------------------------------
    // MARK: - private variables
    private var _format : AVAudioFormat!
    private var _formatDesc : UnsafePointer<AudioStreamBasicDescription>?
    private var _power : Double = 0.0
    private var _averagePower : Double = 0.0
    private var _ambientPower : Double = 0.0
    private var _timeout : Bool = true
    private var _oldDelta : Double = 0.0
    
    //---------------------------------------------------------------
    
    // MARK: - Initializer
    override init() {
        super.init()
        reset()
    }

    // MARK: - Initializer
    init(_ format: AVAudioFormat) {
        super.init()
        reset()
        setup(format)
    }
    
    // MARK: - initialize
    func setup(_ format: AVAudioFormat) {
        _format = format
        _formatDesc = CMAudioFormatDescriptionGetStreamBasicDescription(_format.formatDescription)
    }
    
    // MARK: - Reset
    func reset() {
        _power = 0.0
        _averagePower = 0.0
        _ambientPower = 0.0
        _timeout = true
        _oldDelta = 0.0
        alpha = 0.01
        ambientAlpha = 0.00001
        onThresh = 10.0   // dB
        offThresh = 3.0  // dB
        offDuration = 5.0 // seconds
        isActive = false

    }
    
    // MARK: - Convert PCM buffer to NSData
    func power(_ pcmBuffer: AVAudioPCMBuffer, channel: Int = 0) -> Double {
        let channels = UnsafeBufferPointer(start: pcmBuffer.floatChannelData, count: channelCount)
        var sum = Double(0)
        for i in 0..<pcmBuffer.frameCapacity {
            let x = Double(channels[channel][Int(i)])
            sum = sum + x*x
        }
        _power = 20*log10(sum.squareRoot())
        return _power
    }
    
    // MARK: - Compute average power
    func averagePower(_ pcmBuffer: AVAudioPCMBuffer, channel: Int = 0) -> Double {
        _averagePower = (1.0 - alpha) * _averagePower + alpha * power(pcmBuffer, channel: channel)
        return _averagePower
    }
    
    
    // MARK: - Compute average power
    func ambientPower(_ pcmBuffer: AVAudioPCMBuffer, channel: Int = 0) -> Double {
        _ambientPower = (1.0 - ambientAlpha) * _ambientPower + ambientAlpha * averagePower(pcmBuffer, channel: channel)
        return _ambientPower
    }
    
    // MARK: - Update
    func update(_ pcmBuffer : AVAudioPCMBuffer, channel: Int = 0) -> Bool {
        let ambient = ambientPower(pcmBuffer, channel: channel)
        let delta = _power - ambient
        
        if delta >= onThresh {
            isActive = true
            timer?.invalidate()
        }
        else if _oldDelta > offThresh && delta <= offThresh {
            refreshTimer()
        }
        else if delta <= offThresh && _timeout {
            isActive = false
        }
        _oldDelta = delta
        return isActive
    }

    // MARK: - Refresh timer
    private func refreshTimer() {
        timer?.invalidate()
        self._timeout = false
        timer = nil
        timer = Timer.scheduledTimer(withTimeInterval: offDuration, repeats: false, block: { (timer) in
            self._timeout = true
        })
    }

}
