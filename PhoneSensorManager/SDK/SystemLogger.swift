//
//  SystemLogger.swift
//  Dashphone
//
//  Created by Larry Li on 7/15/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation
import AVFoundation



class SystemLogger : NSObject {

    var logPath : URL?
        
    //==========================================================
    // Constructor
    //==========================================================
    override init() {
        super.init()
        logPath = sys.storage.createFile(name: "systemLog.txt")
        if let path = logPath {
            if sys.storage.removeItem(at: path) == false {
                #if DEBUG
                print("Failed to remove logfile")
                #endif
            }
        }
        logPath = sys.storage.createFile(name: "systemLog.txt")
    }
    
    //==========================================================
    // Log a string
    //==========================================================
    func log(_ module: String, text : String) {
        if let path = logPath {
            _ = storageManager.writeFile(fileURL: path, text: "\(module):\(String(format: "%.6f", CACurrentMediaTime())):\(text)")
            #if DEBUG
            print("\(module):\(String(format: "%.6f", CACurrentMediaTime())):\(text)")
            #endif
        }
    }
    
    //==========================================================
    // Remove the system log
    //==========================================================
    func remove() {
        if let path = logPath {
            _ = storageManager.removeItem(at: path)
        }
    }
    
}
