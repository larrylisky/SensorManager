//
//  Messages.swift
//  Dashphone
//
//  Created by Larry Li on 8/23/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import CoreLocation

//=========================================================
class RequestVideoMessage : Codable {
    var user: String
    var videoOwner: String
    
    init() {
        user = ""
        videoOwner = ""
    }
    
    init(user: String, videoOwner: String) {
        self.user = user
        self.videoOwner = videoOwner
    }
    
    func toJSON() -> String? {
        let jsonData = try! JSONEncoder().encode(self)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
    
    func fromJSON(_ string : String?) -> Bool {
        var rc = false
        
        if let jsonData = string?.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                let message = try decoder.decode(RequestVideoMessage.self, from: jsonData)
                self.user = message.user
                self.videoOwner = message.videoOwner
                rc = true
            }
            catch {
                sys.log("RequestVideoMessage", text: "fromJSON error=\(error.localizedDescription)\n")
            }
        }
        return rc
    }
}


//=========================================================
class UserLocationMessage : Codable {
    var user: String
    var latitude: Double
    var longitude: Double
    var heading: Double
    
    init() {
        user = ""
        latitude = 0.0
        longitude = 0.0
        heading = 0.0
    }
    
    init(user: String, location: CLLocationCoordinate2D, heading: Double) {
        self.user = user
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.heading = heading
    }
    
    init(user: String, latitude: Double, longitude: Double, heading: Double) {
        self.user = user
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
    }
    
    func toJSON() -> String? {
        let jsonData = try! JSONEncoder().encode(self)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
    
    func fromJSON(_ string : String?) -> Bool {
        var rc = false
        
        if let jsonData = string?.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                let message = try decoder.decode(UserLocationMessage.self, from: jsonData)
                self.user = message.user
                self.latitude = message.latitude
                self.longitude = message.longitude
                self.heading = message.heading
                rc = true
            }
            catch {
                sys.log("UserLocationMessage", text: "fromJSON error=\(error.localizedDescription)\n")
            }
        }
        return rc
    }
}


//=========================================================
class AlertMessage : Codable {
    var from: String
    var alert : String
    var location : CLLocationCoordinate2D
    var year : Int
    var month : Int
    var day : Int
    var hour : Int
    var minute : Int
    var second : Int
    
    
    init(from: String, alert: String, location: CLLocationCoordinate2D,
         year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        self.from = from
        self.alert = alert
        self.location = location
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }
    
    func toJSON() -> String? {
        let jsonData = try! JSONEncoder().encode(self)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
    
    func fromJSON(_ string : String?) -> Bool {
        var rc = false
        
        if let jsonData = string?.data(using: .utf8) {
            let decoder = JSONDecoder()
            do {
                let message = try decoder.decode(AlertMessage.self, from: jsonData)
                self.from = message.from
                self.alert = message.alert
                self.location = message.location
                self.year = message.year
                self.month = message.month
                self.day = message.day
                self.hour = message.hour
                self.minute = message.minute
                self.second = message.second
                rc = true
            }
            catch {
                sys.log("AlertMessage", text: "fromJSON error=\(error.localizedDescription)\n")
            }
        }
        return rc
    }
}






