//
//  MeshObjects.swift
//  PhoneSensorManager
//
//  Created by Larry Li on 12/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import Euclid

extension Mesh {
    
    func rotX(rad: Double) -> Mesh {
        let c = cos(rad)
        let s = sin(rad)
        let r = Rotation(1, 0, 0,
                         0, c,-s,
                         0, s, c)
        return rotated(by: r)
    }
    
    func rotY(rad: Double) -> Mesh {
        let c = cos(rad)
        let s = sin(rad)
        let r = Rotation(c, 0, s,
                         0, 1, 0,
                        -s, 0, c)
        return rotated(by: r)
    }
    
    func rotZ(rad: Double) -> Mesh {
        let c = cos(rad)
        let s = sin(rad)
        let r = Rotation(c,-s, 0,
                         s, c, 0,
                         0, 0, 1)
        return rotated(by: r)
    }
    
    func rotX(deg: Double) -> Mesh {
        rotX(rad: deg * Double.pi / 180.0)
    }
    
    func rotY(deg: Double) -> Mesh {
        rotY(rad: deg * Double.pi / 180.0)

    }
    
    func rotZ(deg: Double) -> Mesh {
        rotZ(rad: deg * Double.pi / 180.0)
    }
}

