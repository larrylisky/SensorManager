//
//  CalendarManager.swift
//  Dashphone
//
//  Created by Larry Li on 7/10/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation


class CalendarManager : NSObject {
    
    var localTimeZoneCode : String = TimeZone.current.abbreviation()!
    let _calendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)
    
    //==========================================================
    // Constructor
    //==========================================================
    override init() {
        super.init()
    }
    
    //==========================================================
    // Curent minutes in number spoken spoken string
    //==========================================================
    func second() -> (Int, String) {
        if let calendar = calendar() {
            calendar.timeZone = TimeZone.current
            let components = calendar.components([.second], from: Date())
            let second = components.minute!
            return (second, String(second))
        }
        return (0, "")
    }
    
    //==========================================================
    // Curent minutes in number spoken spoken string
    //==========================================================
    func minute() -> (Int, String) {
        if let calendar = calendar() {
            calendar.timeZone = TimeZone.current
            let components = calendar.components([.minute], from: Date())
            let minute = components.minute!
            return (minute, String(minute))
        }
        return (0, "")
    }
    
    //==========================================================
    // Return hours in number and spoken string
    //==========================================================
    func hour() -> (Int, String) {
        if let calendar = calendar() {
            calendar.timeZone = TimeZone.current
            let components = calendar.components([.hour], from: Date())
            let hour = components.hour!
            return (hour, String(hour))
        }
        return (0, "")
    }
    
    //==========================================================
    // Return date in number and spoken string
    //==========================================================
    func date() -> (String, String) {
        return (weekday().1, month().1 + " " + day().1 + ", " + year().1)
    }
    
    //==========================================================
    // Return weekday in number and spoken string
    //==========================================================
    func weekday() -> (Int, String) {
        if let calendar = calendar() {
            calendar.timeZone = TimeZone.current
            let components = calendar.components([.weekday], from: Date())
            let weekday = components.weekday!
            return (weekday, calendar.weekdaySymbols[weekday-1])
        }
        return (0, "")
    }
    
    //==========================================================
    // Return day of month in number and spoken string
    //==========================================================
    func day() -> (Int, String) {
        if let calendar = calendar() {
            calendar.timeZone = TimeZone.current
            let components = calendar.components([.day], from: Date())
            let day = components.day!
            return (day, String(day))
        }
        return (0, "")
    }
    
    //==========================================================
    // Return month in number and spoken string
    //==========================================================
    func month() -> (Int, String) {
        let (zone, _) = timeZone(code: localTimeZoneCode)
        if let calendar = calendar(), zone != nil {
            calendar.timeZone = zone!
            calendar.locale = .autoupdatingCurrent
            let components = calendar.components([.month], from: Date())
            let month = components.month!
            return (month, calendar.monthSymbols[month-1])
        }
        return (0, "")
    }
    
    
    //==========================================================
    // Return year in number and spoken string
    //==========================================================
    func year() -> (Int, String) {
        if let calendar = calendar() {
            calendar.timeZone = TimeZone.current
            let components = calendar.components([.year], from: Date())
            let year = components.year!
            return (year, String(year))
        }
        return (0, "")
    }
    
    //==========================================================
    // Return a calendar object
    //==========================================================
    func calendar() -> NSCalendar? {
        return _calendar
    }
    
    //==========================================================
    // Return local timeZone object and abbreviation
    //==========================================================
    func timeZone() -> (TimeZone?, String?) {
        var zone : TimeZone?
        var zoneName : String?
        zone = TimeZone(abbreviation: localTimeZoneCode)
        zoneName = zone?.abbreviation()
        return (zone, zoneName)
    }
    
    //==========================================================
    // Return a given timeZone object and abbreviation
    //==========================================================
    func timeZone(code: String?) -> (TimeZone?, String?) {
        var zone : TimeZone?
        var zoneName : String?
        if let code = code {
            zone = TimeZone(abbreviation: code)
            zoneName = zone?.abbreviation()
        }
        return (zone, zoneName)
    }
    
    //==========================================================
    // Create dateTimeString used in video/photo file naming
    //==========================================================
    func dateTimeString() -> String? {
        var utcDateTimeString : String?
        
        if let utcCalendar = calendar() {
            let (utcTimeZone, _) = timeZone(code: "UTC")
            if utcTimeZone != nil {
                utcCalendar.timeZone = utcTimeZone!
                let utcDateComponents = utcCalendar.components([.year, .month, .day, .hour, .minute, .second], from: Date())
                // Create string of form "yyyy-mm-dd-hh-mm-ss"
                utcDateTimeString = String(format: "%04u%02u%02u%02u%02u%02u",
                                                 UInt(utcDateComponents.year!),
                                                 UInt(utcDateComponents.month!),
                                                 UInt(utcDateComponents.day!),
                                                 UInt(utcDateComponents.hour!),
                                                 UInt(utcDateComponents.minute!),
                                                 UInt(utcDateComponents.second!))
            }
        }
        return utcDateTimeString
    }
}
