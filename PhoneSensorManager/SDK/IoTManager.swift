//
//  IoTManager.swift
//  Dashphone
//
//  Created by Larry Li on 7/3/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import Foundation
import Moscapsule
import CoreLocation


//////////////////////////////////////////////////////////////////////////////
//  mqttManagerDelegate
//////////////////////////////////////////////////////////////////////////////
protocol IoTManagerDelegate : NSObjectProtocol {
    func publishCallback(messageId : Int)
    func subscribeCallback(message : MQTTMessage)
}


//////////////////////////////////////////////////////////////////////////////
//  class IoTManager
//////////////////////////////////////////////////////////////////////////////
class IoTManager : NSObject {
    
    var id : String?
    var host : String?
    var client : MQTTClient?
    var config : MQTTConfig?
    weak var delegate : IoTManagerDelegate?
    var pub_count : UInt64 = 0
    var sub_count : UInt64 = 0
    var connected : Bool = false
    var updateInterval : TimeInterval = 1.0

    private var messageCallback : Dictionary< String, (String?)-> Void > = [:]
    private var _timer : Timer?
    
    //==========================================================
    // Constructor
    //==========================================================
    init(id: String) {
        super.init()
        self.id = id
        self.delegate = self
    }
    
    //==========================================================
    // Connect to MQTT hub
    //==========================================================
    open func connect(_ host : String) -> Bool {
       if let id = self.id {
            config = MQTTConfig(clientId: id, host: host,
                            port: 1883, keepAlive: 60, protocolVersion: .v3_1_1)
        
            config?.onPublishCallback = self.delegate?.publishCallback
            config?.onMessageCallback = self.delegate?.subscribeCallback

            client = MQTT.newConnection(config!, connectImmediately: true)
            if client != nil {
                sys.log("IoTManager", text: "connection success - my id = \(id)\n")
                connected = true
                return true
            }
        }
        connected = false
        sys.log("IoTManager", text: "connection failed\n")
        return false
    }
    
    //==========================================================
    // Start IoT, must identify self
    //==========================================================
    func start(_ id: String) {
        self.id = id
        if connect(sys.settings.iotHubAddress) {
            subscribe(topic: "all/location", callback: handleUserLocationUpdate)
            startUpdate()
            sys.log("IoTManager", text:  "Connected to IoT server\n")
        }
        else {
            sys.log("IoTManager", text:  "Failed connecting to IoT server\n")
        }
    }
    
    //==========================================================
    // Handle user pool update
    //==========================================================
    func handleUserLocationUpdate(_ jsonString: String?) {
        if let jsonString = jsonString {
            let message = UserLocationMessage()
            if message.fromJSON(jsonString) {
                sys.log("IoTManager", text: "handling location update from \(message.user), latitude=\(message.latitude), longitude=\(message.longitude),  heading=\(message.heading)\n")
                sys.userPool[message.user] = (message.latitude, message.longitude, message.heading, 2)  // '2 is sustain constant
            }
        }
    }
    
    //==========================================================
    // Stop updating and disconnect from IoT hub
    //==========================================================
    func stop() {
        stopUpdate()
        disconnect()
    }
    
    //==========================================================
    // Disconnect from MQTT hub
    //==========================================================
    open func disconnect() {
        client?.disconnect()
        connected = false
        sys.log("IoTManager", text:  "Disconnected from IoT server\n")
    }
    
    //==========================================================
    // Start agent
    //==========================================================
    func startUpdate() {
        sys.log("IoTManager", text:  "Starting periodic update\n")
        _timer = Timer.scheduledTimer(timeInterval: updateInterval, target: self,
                selector: #selector(self.periodic), userInfo: nil, repeats: true)
    }
    
    //==========================================================
    // Stop agent
    //==========================================================
    func stopUpdate() {
        _timer?.invalidate()
        _timer = nil
        sys.log("IoTManager", text:  "Stopped periodic update\n")
    }
    
    //==========================================================
    // Periodic update of user location
    //==========================================================
    @objc func periodic() {

        if let isConnected = client?.isConnected, let isRunning = client?.isRunning, (isConnected && isRunning) {
            if let id = self.id, let location = sys.map.currentLocation(), let heading = sys.map.currentHeading() {
                let message = UserLocationMessage(user: id, location: location.coordinate, heading: heading.trueHeading)
                if let string = message.toJSON() {
                    publishWithCompletion(topic: "server/location", message: string, completion: { (mosqResult, messageId) in
                        sys.log("IoTManager", text: "Periodic updated\n")
                    })
                }
            }
        }
        else {
            sys.log("IoTManager", text: "Reconnecting...\n")
            client?.reconnect()
        }
    }
    
    //==========================================================
    // Subscribe to any topics
    //==========================================================
    open func subscribe(topic: String, callback: @escaping (String?) -> Void) {
        client?.subscribe(topic, qos: 0)
        messageCallback[topic] = callback
    }
    
    //==========================================================
    // Subscribe to my own message
    //==========================================================
    open func subscribeToMyMessage(subtopic: String, callback: @escaping (String?) -> Void) {
        subscribe(topic: id!+"/"+subtopic, callback: callback)
    }
    
    //==========================================================
    // Publish a message to subscriber without completion
    //==========================================================
    open func publish(topic: String, message: String) {
        client?.publish(string: message, topic: topic, qos: 0, retain: false)
    }
    
    //==========================================================
    // Publish a message to subscriber with completion
    //==========================================================
    open func publishWithCompletion(topic: String, message: String, completion: @escaping (MosqResult, Int) -> ()) {
        client?.publish(string: message, topic: topic, qos: 0, retain: false, requestCompletion: completion)
    }
    
    
    //==========================================================
    // Publish a message to /server topic without completion
    //==========================================================
    func publishToServer(_ message : String?) {
        let text = (message == nil) ? "" : message!
        publish(topic: "server", message: text)
    }
    
    //==========================================================
    // Publish a message to server topic with completion
    //==========================================================
    open func publishToServerWithCompletion(message: String, completion: @escaping (MosqResult, Int) -> ()) {
        publishWithCompletion(topic: "server", message: message, completion: completion)
    }
    
    //==========================================================
    // Clear all registered callback
    //==========================================================
    open func clearCallback() {
        messageCallback.removeAll()
    }
}

///////////////////////////////////////////////////////////////////////////////
// mqttManagerDelegate
///////////////////////////////////////////////////////////////////////////////
extension IoTManager : IoTManagerDelegate {
    
    //==========================================================
    // Publish callback
    //==========================================================
    func publishCallback(messageId : Int) {
        pub_count = pub_count+1
    }
    
    //==========================================================
    // Subscribe callback
    //==========================================================
    func subscribeCallback(message : MQTTMessage) {
        sub_count = sub_count+1
        if let callback = messageCallback[message.topic] {
            callback(message.payloadString)
        }
    }
}
