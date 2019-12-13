//
//  storageManager.swift
//  Dashphone
//
//  Created by Larry Li on 7/10/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation


class StorageManager : NSObject {
    
    let fileManager = FileManager.default
    let root = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    let rootPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    
    
    //==========================================================
    // Create directory
    //==========================================================
    open func createDirectory(directory: String) -> Bool {
        do {
            try fileManager.createDirectory(atPath: root! + "/" + directory, withIntermediateDirectories: true, attributes: nil)
            return true
        }
        catch let error as NSError {
            print(error.localizedDescription);
            return false
        }
    }
    
    //==========================================================
    // Create a file
    //==========================================================
    open func createFile(name: String) -> URL? {
        var filePath : URL?
        filePath = rootPath?.appendingPathComponent(name)
        return filePath
    }
    
    
    //==========================================================
    // Write to file
    //==========================================================
    open func writeFile(fileURL: URL?, text: String) -> Bool {
        if let url = fileURL {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: url)
                    fileHandle.seekToEndOfFile()
                    let data = text.data(using: String.Encoding.utf8, allowLossyConversion: false)!
                    fileHandle.write(data)
                    fileHandle.closeFile()
                    return true
                }
                catch {
                    return false
                }
            }
            else {
                do {
                    try text.write(to: url, atomically: false, encoding: .utf8)
                    return true
                }
                catch {
                    return false
                }
            }
        }
        return false
    }
    
    //==========================================================
    // Read from file
    //==========================================================
    open func readFile(fileURL: URL?) -> (Bool, String?) {
        var text : String?
        if let url = fileURL {
            do {
                text = try String(contentsOf: url, encoding: .utf8)
                return (true, text)
            }
            catch {
                return (false, text)
            }
        }
        return (false, text)
    }
    
    //==========================================================
    // Move file or directory or other URL resource
    //==========================================================
    open func moveItem(at: URL, to: URL) -> Bool {
        do {
            try fileManager.moveItem(at: at, to: to)
            return true
        }
        catch {
            return false
        }
    }

    //==========================================================
    // Copy file or directory or other URL resource
    //==========================================================
    open func copyItem(at: URL, to: URL) -> Bool {
        do {
            try fileManager.copyItem(at: at, to: to)
            return true
        }
        catch {
            return false
        }
    }
    
    //==========================================================
    // Remove file or directory or other URL resource
    //==========================================================
    open func removeItem(at: URL) -> Bool {
        do {
            try fileManager.removeItem(at: at)
            return true
        }
        catch {
            return false
        }
    }
    
    //==========================================================
    // List URL resource in a directory into an array
    //==========================================================
    open func listDirectory(_ directory: String) -> [URL] {
        var directoryContents : [URL] = []
        do {
            if let Path = rootPath?.appendingPathComponent(directory).absoluteURL {
                directoryContents = try FileManager.default.contentsOfDirectory(at: Path, includingPropertiesForKeys: nil, options: [])
            }
        }
        catch {
        }
        return directoryContents
    }
    
    //==========================================================
    // Check if a given path exists
    //==========================================================
    open func pathExist(_ path: String) -> (Bool, Bool) {
        var isDir = ObjCBool(false)
        let exist = fileManager.fileExists(atPath: path, isDirectory: &isDir)
        return (exist, isDir.boolValue)
    }
    
    //==========================================================
    // Check if a given URL resource exists
    //==========================================================
    open func pathExist(_ url: URL) -> (Bool, Bool) {
        var isDir = ObjCBool(false)
        let exist = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return (exist, isDir.boolValue)
    }
    
}
