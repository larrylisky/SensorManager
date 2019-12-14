//
//  Fifo.swift
//  PhoneSensorManager
//
//  Created by Larry Li on 12/13/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Foundation

// Fifo is a circular buffer of Doubles
// Head is the index of beginning of buffer (oldest value)
// Tail is the index of end of buffer (newest value)
// pop() from head, push() to tail
class Fifo {
    var data : [Double]
    var head : Int
    var tail : Int
    var max : Int
    var count : Int
    
    init(_ size: Int) {
        data = []
        head = 0
        tail = 0
        count = 0
        max = size
    }
    
    func push(_ value: Double) {
        if data.count < max {
            data.append(value)
        }
        else {
            if tail == head {
                head = (head + 1) % max
            }
            data[tail] = value
        }
        tail = (tail + 1) % max
        if (count < max) {
            count = count + 1
        }
    }
    
    func pop() -> Double {
        var retVal : Double = 0.0
        
        if isEmpty() {
            return retVal
        }
        else {
            retVal = data[head]
            head = (head + 1) % max
            if tail == head {
                tail = (tail + 1) % max
            }
            if (count > 0) {
                count = count - 1
            }
        }
        return retVal
    }
    
    func isEmpty() -> Bool {
        return count == 0
    }
    
    func dump() {
        print("h:\(head) t:\(tail) \(data)")
    }
    
    static func test() {
        let fifo = Fifo(5)
        for i in 0..<7 {
            fifo.push(Double(i))
            fifo.dump()
        }
        for _ in 0..<7 {
            if fifo.isEmpty() {
                print("Empty")
            }
            else {
                print("pop \(fifo.pop())")
                fifo.dump()
            }
        }
    }
}
