//
//  TripAlert.swift
//  Dashphone
//
//  Created by Larry Li on 8/2/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import Foundation
import CoreLocation


class TripAlert : NSObject {
    
    enum Alert : String {
        case accident = "accident"
        case construction = "construction"
        case debris = "debris"
        case congestion = "congestion"
        case roadDamage = "road damage"
        case flooding = "flooding"
        case police = "police"
        case stall = "stall"
        static let allValues = [accident, construction, debris, congestion, roadDamage, flooding, police, stall]
    }
    
    //==========================================================
    // Encode AlertReport into JSON string
    //==========================================================
    init(_ alert: Alert) {
        super.init()
 
        let (year, _) = sys.calendar.year()
        let (month, _) = sys.calendar.month()
        let (day, _) = sys.calendar.day()
        let (minute, _) = sys.calendar.minute()
        let (hour, _) = sys.calendar.hour()
        let (second, _) = sys.calendar.second()
        
        var currentLocation: CLLocation?
        
        if let location = sys.map.currentLocation() {
            currentLocation = location
        }
        else if let location = sys.sensor.currentLocation {
            currentLocation = location
        }
        
        if let location = currentLocation, let id = sys.iot.id {
            let report = AlertMessage(
                from: id,
                alert: alert.rawValue,
                location: location.coordinate,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second)
            
            sendToServer(report)
        }
    }
    
    //==========================================================
    // Encode mqttMessage into JSON string
    //==========================================================
    func sendToServer(_ report: AlertMessage) {
        if let message = report.toJSON() {
            sys.iot.publishToServer(message)
        }
    }
    
    //==========================================================
    // Encode mqttMessage into JSON string
    //==========================================================
    func textOf(_ alert: Alert) -> String {
        return alert.rawValue
    }
}
