//
//  CMRotationMatrixExt.swift
//  PhoneSensorManager
//
//  Created by Larry Li on 12/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

import CoreMotion

extension CMRotationMatrix {
    
    // Return an identify matrix
    func identity() -> CMRotationMatrix {
        return CMRotationMatrix(m11: 1.0, m12: 0.0, m13: 0.0,
                                m21: 0.0, m22: 1.0, m23: 0.0,
                                m31: 0.0, m32: 0.0, m33: 1.0)
    }
    
    // Premultiple by matrix 'm'
    static func *(left: CMRotationMatrix, right:CMRotationMatrix) -> CMRotationMatrix {
        return CMRotationMatrix(
            m11: left.m11*right.m11 + left.m12*right.m21 + left.m13*right.m31,
            m12: left.m11*right.m12 + left.m12*right.m22 + left.m13*right.m32,
            m13: left.m11*right.m13 + left.m12*right.m23 + left.m13*right.m33,
            m21: left.m21*right.m11 + left.m22*right.m21 + left.m23*right.m31,
            m22: left.m21*right.m12 + left.m22*right.m22 + left.m23*right.m32,
            m23: left.m21*right.m13 + left.m22*right.m23 + left.m23*right.m33,
            m31: left.m31*right.m11 + left.m32*right.m21 + left.m33*right.m31,
            m32: left.m31*right.m12 + left.m32*right.m22 + left.m33*right.m32,
            m33: left.m31*right.m13 + left.m32*right.m23 + left.m33*right.m33)
    }


    // Return inverse of self
    // From http://mathworld.wolfram.com/MatrixInverse.html
    func inverse() -> CMRotationMatrix {
        let a = CMRotationMatrix(
                    m11: m22*m33-m23*m32,       m12: m13*m32-m12*m33,       m13: m12*m23-m13*m22,
                    m21: m23*m31-m21*m33,       m22: m11*m33-m13*m31,       m23: m13*m21-m11*m23,
                    m31: m21*m32-m22*m31,       m32: m12*m31-m11*m32,       m33: m11*m22-m12*m21)
        
        var determinant = m11*(m22*m33-m23*m32) - m12*(m21*m33-m23*m31) + m13*(m21*m32-m22*m31)

        if determinant > 0.1 && determinant <= 1.1 {
            determinant = 1.0
            let inv = CMRotationMatrix(
                m11: a.m11/determinant, m12: a.m12/determinant, m13: a.m13/determinant,
                m21: a.m21/determinant, m22: a.m22/determinant, m23: a.m23/determinant,
                m31: a.m31/determinant, m32: a.m32/determinant, m33: a.m33/determinant)
            return inv
        }
        else{
            return identity()
        }
    }
    
    func rotateX(rad: Double) -> CMRotationMatrix {
        let c = cos(rad)
        let s = sin(rad)
        return CMRotationMatrix(
            m11: 1, m12: 0, m13: 0,
            m21: 0, m22: c, m23:-s,
            m31: 0, m32: s, m33: c)
    }
    
    func rotateY(rad: Double) -> CMRotationMatrix {
        let c = cos(rad)
        let s = sin(rad)
        return CMRotationMatrix(
            m11: c, m12: 0, m13: s,
            m21: 0, m22: 1, m23: 0,
            m31:-s, m32: 0, m33: c)
    }
    
    func rotateZ(rad: Double) -> CMRotationMatrix {
        let c = cos(rad)
        let s = sin(rad)
        return CMRotationMatrix(
            m11: c, m12:-s, m13: 0,
            m21: s, m22: c, m23: 0,
            m31: 0, m32: 0, m33: 1)
    }
}
