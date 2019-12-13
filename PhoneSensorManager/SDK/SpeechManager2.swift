//
//  speechManager.swift
//  Dashphone
//
//  Created by Larry Li on 7/10/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import Speech


//----------------------------------------------------------
// SpeechManagerOutputDelegate
//----------------------------------------------------------
protocol SpeechManagerOutputDelegate : class {
    func processOutput(manager : SpeechManager, input: String)
}

//----------------------------------------------------------
// SpeechManagerActivityDelegate
//----------------------------------------------------------
protocol SpeechManagerActivityDelegate : class {
    func activityChange(from: Bool, to: Bool)
}


//----------------------------------------------------------
// class SpeechManager
//----------------------------------------------------------
class SpeechManager : NSObject {
    
    // Public variable
    var name : String?
    weak var outputDelegate : SpeechManagerOutputDelegate?
    weak var activityDelegate : SpeechManagerActivityDelegate?
    var powerMeter : SoundMeter?

    // Basic
    private var listening : Bool = false
    private var timer : Timer?
    private let maxPauseBetweenWords : TimeInterval = 3.0  // seconds
    private var available = false
    private var active = false
    
    // Speech recognition parameters
    private let audioEngine = AVAudioEngine()
    private var request : SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask : SFSpeechRecognitionTask?
    private let tagger = NSLinguisticTagger(tagSchemes: [NSLinguisticTagScheme.tokenType, .language, .lexicalClass, .nameType, .lemma], options: 0)
    private let options: NSLinguisticTagger.Options = [NSLinguisticTagger.Options.omitPunctuation, .omitWhitespace, .joinNames]
    private var inputString : String = ""
    
    // Speech synthesis parameters
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var voice = AVSpeechSynthesisVoice(language: "en-US")
    private var speechQueue = DispatchQueue(label: "speech queue")
    
    
    //==========================================================
    // Constructor
    //==========================================================
    init(name: String) {
        super.init()
        self.name = name.lowercased()
        speechSynthesizer.delegate = self
        request = SFSpeechAudioBufferRecognitionRequest()

    }
    
    //==========================================================
    // Check if speechManager is available
    //==========================================================
    open func isAvailable() -> Bool {
        return available
    }
    
    //==========================================================
    // First time starting the speechManager requiring
    // authorizaton and self-introduction
    //==========================================================
    open func firstStart() {
        requestAuthorization()
    }
    
    //==========================================================
    // Start speech manager
    //==========================================================
    open func start() {
        startRecognition()
    }
    
    //==========================================================
    // Stop speech manager, stop timer callback
    //==========================================================
    open func stop() {
        timer?.invalidate()
        timer = nil
        stopRecognition {}
    }
    
    //==========================================================
    // Speak a given string.
    // AVSpeechUtteranceDefaultSpeechRate is 0.5
    //==========================================================
    open func speak(_ string : String, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stopRecognition(completion: { [weak self] in
            let utterance = AVSpeechUtterance(string: string)
            utterance.rate = rate
            utterance.rate = rate
            utterance.voice = self?.voice
            self?.speechSynthesizer.speak(utterance)
        })
    }
    
    //==========================================================
    // Pause speaking at AVSpeechBoundary.word or
    // AVSpeechBoundar.immediate
    //==========================================================
    open func pauseSpeaking(boundary: AVSpeechBoundary) -> Bool {
        var ret : Bool = false
        if isSpeaking() {
            sys.log("SpeechManager", text: "paused speaking\n")
            ret = speechSynthesizer.pauseSpeaking(at: boundary)
        }
        return ret
    }
    
    //==========================================================
    // Stop speaking at AVSpeechBoundary.word
    //==========================================================
    open func stopSpeaking() -> Bool {
        var ret : Bool = false
        if isSpeaking() {
            sys.log("SpeechManager", text: "paused speaking\n")
            ret = speechSynthesizer.stopSpeaking(at: .word)
        }
        return ret
    }
    
    //==========================================================
    // Resume speaking
    //==========================================================
    open func resumeSpeaking() -> Bool {
        var ret : Bool = false
        if (isPaused()) {
            sys.log("Speech", text: "resume speaking\n")
            ret = speechSynthesizer.continueSpeaking()
        }
        return ret
    }
    
    //==========================================================
    // Check if speaking
    //==========================================================
    open func isSpeaking() -> Bool {
        return speechSynthesizer.isSpeaking
    }
    
    //==========================================================
    // Check if speaking paused
    //==========================================================
    open func isPaused() -> Bool {
        return speechSynthesizer.isPaused
    }

    //==========================================================
    // Play self introduction
    //==========================================================
    open func playIntro() {
        speak("Hi, I am " + self.name! + ", your virtual driver assistant.")
    }
    
    //==========================================================
    // Call delegate to update activity
    //==========================================================
    private func activityUpdate(_ toActivity: Bool) {
        let fromActivity = active
        active = toActivity
        sys.log("SpeechManager", text: "activity update from \(fromActivity) to \(toActivity) \n")
        if fromActivity != toActivity {
            activityDelegate?.activityChange(from: fromActivity, to: toActivity)
        }
    }
    
    //==========================================================
    // Request for speech recognition authorization
    //==========================================================
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    sys.log("SpeechManager", text: "recognition authorized\n")
                    self.outputDelegate = sys.command
                    var prompt : [String] = []
                    if let name = self.name {
                        prompt.append("hey " + name)
                        prompt.append("hello " + name)
                        prompt.append("hi " + name)
                        prompt.append(name)
                    }
                    sys.command.setup(prompt: prompt)
                    self.startRecognition()
                    self.playIntro()
                default:
                    sys.log("SpeechManager", text: "recognition not authorized\n")
                    sys.showAlert(title: "Speech Recognizer", message: "Not authorized", prompt: "Ok")
                    while (true) { sleep (1000) }  // spin loop
                }
            }
        }
    }
    
    //==========================================================
    // Start speech recognition from microphone
    //==========================================================
    open func startRecognition() {
        
        speechQueue.async {
            if !self.listening {
                self.listening = true
                sys.log("SpeechManager", text: "start recognition\n")

                // Audio setup
                let node = self.audioEngine.inputNode
                self.request = SFSpeechAudioBufferRecognitionRequest()
                let recordingFormat = node.outputFormat(forBus: 0)
                //self.powerMeter = SoundMeter(recordingFormat)
                /*
                if self.powerMeter!.formatOK {
                    print("channels = \(self.powerMeter!.channelCount)")
                    print("bitsPersSample = \(self.powerMeter!.bitsPersSample)")
                    print("bytesPerFrame = \(self.powerMeter!.bytesPerFrame)")
                    print("sampleRAte = \(self.powerMeter!.sampleRate)")
                    print("isInterleaved = \(self.powerMeter!.isInterleaved)")
                }
                */
                node.installTap(onBus: 0, bufferSize: 4800, format: recordingFormat) { [weak self] buffer, _ in
                    self?.request?.append(buffer)
                    
                    /*
                    let isActive = self?.powerMeter!.update(buffer)
                    if isActive! {
                        print("))))))))))))))))))))))))))))")
                        self?.request?.append(buffer)
                    }
                    */
                }
                self.audioEngine.prepare()
                
                // Start refresh timer
                DispatchQueue.main.async {
                    self.refreshSpeechTimer("'inside startRecognition()'")
                }
                
                do {
                    try self.audioEngine.start()
                }
                catch {
                    sys.log("SpeechManager", text: "audioEngine start error\n")
                    return
                }
                
                guard let recognizer = SFSpeechRecognizer() else { return }
                self.available = recognizer.isAvailable
                if !self.available {
                    sys.log("SpeechManager", text: "recognizer unavailable\n")
                    return
                }
                
                self.recognitionTask = recognizer.recognitionTask(with: self.request!, resultHandler: { [weak self] result, error in
                    if let result = result {
                        sys.log("SpeechManager", text: "recognizer task active\n")
                        self?.activityUpdate(true)
                        // if result is the same, allow to time out
                        if self?.inputString != result.bestTranscription.formattedString {
                            sys.log("SpeechManager", text: "transcript='\(result.bestTranscription.formattedString)'\n")
                            self?.inputString = result.bestTranscription.formattedString
                            self?.refreshSpeechTimer("inside result")
                        }
                    }
                    else {
                        sys.log("SpeechManager", text: "recognizer task result=nil\n")
                        if let error = error {
                            sys.log("SpeechManager", text: "recognizer task error=\(error)\n")
                            self?.activityUpdate(false)
                        
                            let parts = error.localizedDescription.split(separator: " ", maxSplits: 100, omittingEmptySubsequences: true)
                            for part in parts {
                                if (part == "Message=Quota") {
                                    sys.log("SpeechManager", text: "quota exceeded, speechManager is now unavailable\n")
                                    self?.available = false
                                    return
                                }
                            }
                            
                        }
                    }
                })
            } // if listening
        } // speechQueue
        
    }
    
    //==========================================================
    // Stop recognition
    //==========================================================
    open func stopRecognition(completion: @escaping ()->Void) {
        speechQueue.async {
            if self.listening {
                self.listening = false
                sys.log("SpeechManager", text: "stop recognition\n")
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.audioEngine.inputNode.reset()
                self.audioEngine.stop()
                self.request?.endAudio()
                self.recognitionTask?.cancel()
                self.recognitionTask = nil
                self.request = nil
                completion()
            }
        } // speechQueue
    }

    //==========================================================
    // Restart speech recognition
    //==========================================================
    private func restartRecognition() {
        sys.log("SpeechManager", text: "restart recognition\n")
        stopRecognition(completion: { [weak self] in
            self?.startRecognition()
        })
    }
    
    //==========================================================
    // Restart speech recognition after 'n' seconds
    //==========================================================
    private func refreshSpeechTimer(_ calledFrom: String) {
        sys.log("SpeechManager", text: "refresh speech timer called from \(calledFrom)\n")
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(withTimeInterval: maxPauseBetweenWords, repeats: false, block: { (timer) in
            DispatchQueue.main.async {
                sys.log("SpeechManager", text: "speech timer expired\n")
                self.activityUpdate(false)
                if self.inputString.count > 0 {
                    self.outputDelegate?.processOutput(manager: self, input: self.inputString.lowercased())
                    self.inputString = ""
                }
                self.restartRecognition()
            }
        })
    }

    //==========================================================
    // Extract parts of speech from a given string
    //==========================================================
    open func partOfSpeech(input: String) -> [(String, NSLinguisticTag)] {

        sys.log("SpeechManager", text: "extracting POS for '\(input)'\n")

        var results : [(String, NSLinguisticTag)] = []
        let range = NSRange(location: 0, length: input.utf16.count)
        tagger.string = input

        if #available(iOS 11.0, *) {
           tagger.enumerateTags(in: range, unit: NSLinguisticTaggerUnit.word, scheme: NSLinguisticTagScheme.lexicalClass, options: options) { (tag, tokenRange, _) in
                if let tag = tag {
                    let word = (input as NSString).substring(with: tokenRange)
                    results.append((word, tag))
                    #if DEBUG
                    print("\(word)(\(tag.rawValue)) ", terminator:"")
                    #endif
                }
            } // end closure
        } else {
            sys.log("SpeechManager", text: "Linguistic tagger unavailable\n")
        }
        return results
    }
}


//////////////////////////////////////////////////////////////////////////////////
// SFSpeechRecognizerDelegate
//////////////////////////////////////////////////////////////////////////////////
extension SpeechManager : SFSpeechRecognizerDelegate {
    
    // This function is called if the speech recognizer availability changed due to weak Internet connection
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !self.available && available {
            sys.log("SpeechManager", text: "speech recognizer became available\n")
            self.available = true
            restartRecognition()
        }
        else {
            sys.log("SpeechManager", text: "speech recognizer became unavailable\n")
            self.available = false
        }
    }
    
}

//////////////////////////////////////////////////////////////////////////////////
// AVSpeechSynthesizerDelegate
//////////////////////////////////////////////////////////////////////////////////
extension SpeechManager : AVSpeechSynthesizerDelegate {
    
    // Called right after speaking started
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    }
    
    // Called right after speaking finished
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        sys.log("SpeechManager", text: "finished speaking\n")
        startRecognition()
    }
    
    // Called right after speaking paused
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
    }
    
    // Called right after speaking resumed
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
    }
    
    // Called right after speaking canceled
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    }
    
    // Called right before speaking starts
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
    }
}

