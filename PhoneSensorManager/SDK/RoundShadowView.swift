//
//  RoundShadowView.swift
//  Dashphone
//
//  Created by Larry Li on 8/17/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//

/*
 Example of how to create a view that has rounded corners and a shadow.
 These cannot be on the same layer because setting the corner radius requires masksToBounds = true.
 When it's true, the shadow is clipped.
 It's possible to add sublayers and set their path with a UIBezierPath(roundedRect...), but this becomes difficult when using AutoLayout.
 Instead, we a containerView for the cornerRadius and the current view for the shadow.
 All subviews should just be added and constrained to the containerView
 */

import UIKit

class RoundShadowView: UIView {
    
    var cornerRadius: CGFloat {
        set {
            layer.cornerRadius = newValue
            containee.layer.cornerRadius = newValue
        }
        get {
            return containee.layer.cornerRadius
        }
    }
    var backgroundcolor: CGColor? {
        set {
            containee.layer.backgroundColor = newValue
        }
        get {
            return containee.layer.backgroundColor
        }
    }
    var shadowColor: CGColor? {
        set {
            containee.layer.shadowColor = newValue
        }
        get {
            return containee.layer.shadowColor
        }
    }
    var shadowOffset: CGSize {
        set {
            containee.layer.shadowOffset = newValue
        }
        get {
            return containee.layer.shadowOffset
        }
    }
    var shadowOpacity: Float {
        set {
            containee.layer.shadowOpacity = newValue
        }
        get {
            return containee.layer.shadowOpacity
        }
    }
    var shadowRadius: CGFloat {
        set {
            containee.layer.shadowRadius = newValue
        }
        get {
            return containee.layer.shadowRadius
        }
    }
    var masksToBounds: Bool {
        set {
            containee.layer.masksToBounds = newValue
        }
        get {
            return containee.layer.masksToBounds
        }
    }
    
    var containee = UIView()
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // set the cornerRadius of the containerView's layer
        cornerRadius = 0
        masksToBounds = true
        backgroundColor = .white
        shadowRadius = 0
        shadowOpacity = 0
        shadowColor = UIColor.white.cgColor
        shadowOffset = CGSize(width: 0, height: 0)
        addSubview(containee)
        
        // add constraints
        containee.translatesAutoresizingMaskIntoConstraints = false
        containee.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        containee.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        containee.topAnchor.constraint(equalTo: topAnchor).isActive = true
        containee.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
}
