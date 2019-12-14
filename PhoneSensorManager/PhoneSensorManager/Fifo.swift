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
class Fifo<T> {
    var data : [T]
    var head : Int
    var tail : Int
    var max : Int
    var count : Int
    var inv : T
    
    init(_ size: Int, invalid: T) {
        data = []
        head = 0
        tail = 0
        count = 0
        max = size
        inv = invalid
    }
    
    func copy(_ from: Fifo<T>) {
        if !from.isEmpty() {
            for i in 0..<from.count {
                data.append(from.data[i])
            }
            head = from.head
            tail = from.tail
            max = from.max
            count = from.count
            inv = from.inv
        }
    }
    
    func push(_ value: T) {
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
    
    func pop() -> T {
        var retVal : T
        
        if isEmpty() {
            return inv
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
            return retVal
        }
    }
    
    func isEmpty() -> Bool {
        return count == 0
    }
    
    func get() -> [T] {
        var out : [T] = []
        let cp = Fifo<T>(max, invalid: inv)
        cp.copy(self)
        while !cp.isEmpty() {
            out.append(cp.pop())
        }
        return out
    }
    
    func dump() {
        print("h:\(head) t:\(tail) \(data)")
    }
    
    static func test() {
        let fifo = Fifo<Double>(5, invalid: 0)
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
