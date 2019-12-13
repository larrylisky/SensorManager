//
//  FacialFeaturesExtrctor.swift
//  Dashphone
//
//  Created by Larry Li on 7/27/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import Foundation
import UIKit
import Vision
import CoreGraphics


class FacialFeaturesExtractor: NSObject {
    
    var faceRect : CGRect?
    
    var leftEye: [CGPoint] = []
    var rightEye: [CGPoint] = []
    var leftEyebrow: [CGPoint] = []
    var rightEyebrow: [CGPoint] = []
    var nose: [CGPoint] = []
    var outerLips: [CGPoint] = []
    var innerLips: [CGPoint] = []
    var faceContour: [CGPoint] = []
    var leftPupil: [CGPoint] = []
    var rightPupil: [CGPoint] = []
    
    var shapeLayers : [CAShapeLayer] = []
    var textLayers : [CATextLayer] = []
    var view : UIView?
    
        
    //==========================================================
    //  Convert landmark points to one suitable for view
    //==========================================================
    init(view: UIView, result: VNFaceObservation) {
        super.init()
        self.view = view
        extractLandmarksForView(result: result)
    }
    
    //==========================================================
    //  Destructor
    //==========================================================
    deinit {
        removeAll()
    }
    
    //==========================================================
    //  Create new shape layer
    //==========================================================
    func createShapeLayer() -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.isHidden = false
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayers.append(shapeLayer)
        view?.layer.addSublayer(shapeLayer)
        return shapeLayer
    }
    
    //==========================================================
    //  Create new text layer
    //==========================================================
    func createTextLayer(label: String, origin: CGPoint) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.isHidden = false
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.fontSize = 14
        textLayer.font = UIFont(name: "Avenir", size: textLayer.fontSize)
        textLayer.alignmentMode = CATextLayerAlignmentMode.center
        
        let attributes = [
            NSAttributedString.Key.font: textLayer.font as Any
        ]
        
        let textRect = label.boundingRect(with: CGSize(width: 400, height: 100),
                                          options: .truncatesLastVisibleLine,
                                          attributes: attributes, context: nil)
        let textSize = CGSize(width: textRect.width + 12, height: textRect.height)
        let textOrigin = CGPoint(x: origin.x - 2, y: origin.y - textSize.height)
        textLayer.frame = CGRect(origin: textOrigin, size: textSize)
        
        textLayers.append(textLayer)
        view?.layer.addSublayer(textLayer)
        
        return textLayer
    }
    
    //==========================================================
    //  Convert landmark points to one suitable for view
    //==========================================================
    func convertFor(point: CGPoint) -> CGPoint? {
        var retPoint : CGPoint?
        if let view = self.view {
            retPoint = CGPoint(x: point.y * view.bounds.width, y: point.x * view.bounds.height)
        }
        return retPoint
    }
    
    //==========================================================
    //  Convert landmark size to one suitable for view
    //==========================================================
    func convertFor(size: CGSize) -> CGSize? {
        var retSize : CGSize?
        if let view = self.view {
            retSize = CGSize(width: size.height * view.bounds.width, height: size.width * view.bounds.height)
        }
        return retSize
    }
    
    //==========================================================
    //  Convert landmark Rect to one suitable for view
    //==========================================================
    func convertFor(rect: CGRect) -> CGRect? {
        var retRect : CGRect?
        if let view = self.view {
            retRect = CGRect(
                origin: CGPoint(x: rect.origin.y * view.bounds.width, y: rect.origin.x * view.bounds.height),
                size: CGSize(width: rect.size.height * view.bounds.width, height: rect.size.width * view.bounds.height))
        }
        return retRect
    }
    
    //==========================================================
    //  Convert to a point to its absolute coordinates
    //==========================================================
    func landmark(point: CGPoint, to rect: CGRect) -> CGPoint? {
        let absolute = CGPoint(x: point.x * rect.size.width + rect.origin.x, y: point.y * rect.size.height + rect.origin.y)
        let converted = convertFor(point: absolute)
        return converted
    }
    
    //==========================================================
    //  Video recording button callback
    //==========================================================
    func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
        guard let points = points else {
            return nil
        }
        return points.compactMap { landmark(point: $0, to: rect) }
    }
    
    //==========================================================
    //  Video recording button callback
    //==========================================================
    func extractLandmarksForView(result: VNFaceObservation) {
        
        let box = result.boundingBox
        faceRect = convertFor(rect: box)
        
        guard let landmarks = result.landmarks else {
            return
        }
        
        if let leftEye = landmark(
            points: landmarks.leftEye?.normalizedPoints,
            to: result.boundingBox) {
            self.leftEye = leftEye
        }
        
        if let rightEye = landmark(
            points: landmarks.rightEye?.normalizedPoints,
            to: result.boundingBox) {
            self.rightEye = rightEye
        }
        
        if let leftEyebrow = landmark(
            points: landmarks.leftEyebrow?.normalizedPoints,
            to: result.boundingBox) {
            self.leftEyebrow = leftEyebrow
        }
        
        if let rightEyebrow = landmark(
            points: landmarks.rightEyebrow?.normalizedPoints,
            to: result.boundingBox) {
            self.rightEyebrow = rightEyebrow
        }
        
        if let nose = landmark(
            points: landmarks.nose?.normalizedPoints,
            to: result.boundingBox) {
            self.nose = nose
        }
        
        if let outerLips = landmark(
            points: landmarks.outerLips?.normalizedPoints,
            to: result.boundingBox) {
            self.outerLips = outerLips
        }
        
        if let innerLips = landmark(
            points: landmarks.innerLips?.normalizedPoints,
            to: result.boundingBox) {
            self.innerLips = innerLips
        }
        
        if let faceContour = landmark(
            points: landmarks.faceContour?.normalizedPoints,
            to: result.boundingBox) {
            self.faceContour = faceContour
        }
        
        if let leftPupil = landmark(
            points: landmarks.leftPupil?.normalizedPoints,
            to: result.boundingBox) {
            self.leftPupil = leftPupil
        }
        
        if let rightPupil = landmark(
            points: landmarks.rightPupil?.normalizedPoints,
            to: result.boundingBox) {
            self.rightPupil = rightPupil
        }
    }
    
    //==========================================================
    //  Clear all features
    //==========================================================
    func clear() {
        leftEye = []
        rightEye = []
        leftEyebrow = []
        rightEyebrow = []
        nose = []
        outerLips = []
        innerLips = []
        faceContour = []
        leftPupil = []
        rightPupil = []
        faceRect = .zero
    }
    
    //==========================================================
    //  Remove all features
    //==========================================================
    func removeAll() {
        for shapeLayer in shapeLayers {
            shapeLayer.removeFromSuperlayer()
        }
        for textLayer in textLayers {
            textLayer.removeFromSuperlayer()
        }
        shapeLayers.removeAll()
        textLayers.removeAll()
        leftEye.removeAll()
        rightEye.removeAll()
        leftEyebrow.removeAll()
        rightEyebrow.removeAll()
        nose.removeAll()
        outerLips.removeAll()
        innerLips.removeAll()
        faceContour.removeAll()
        leftPupil.removeAll()
        rightPupil.removeAll()
        faceRect = nil
    }
    
    //==========================================================
    //  Remove all features
    //==========================================================
    func show() {

        CATransaction.setDisableActions(true) // delay display action
        shapeLayers.removeAll()
        textLayers.removeAll()
        // Face
        if let rect = faceRect {
            let path = UIBezierPath(rect: rect)
            let shapeLayer = createShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.lineWidth = 1
            shapeLayer.strokeColor = UIColor.yellow.cgColor
            let textLayer = createTextLayer(label: "Face", origin: rect.origin)
            textLayer.foregroundColor = UIColor.yellow.cgColor
        }
        
        // Left eye
        if !leftEye.isEmpty {
            let path = UIBezierPath()
            path.move(to: leftEye[0])
            for i in 1..<leftEye.count {
                path.addLine(to: leftEye[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // Right eye
        if !rightEye.isEmpty {
            let path = UIBezierPath()
            path.move(to: rightEye[0])
            for i in 1..<rightEye.count {
                path.addLine(to: rightEye[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // Left brow
        if !leftEyebrow.isEmpty {
            let path = UIBezierPath()
            path.move(to: leftEyebrow[0])
            for i in 1..<leftEyebrow.count {
                path.addLine(to: leftEyebrow[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // Right brow
        if !rightEyebrow.isEmpty {
            let path = UIBezierPath()
            path.move(to: rightEyebrow[0])
            for i in 1..<rightEyebrow.count {
                path.addLine(to: rightEyebrow[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // Noise
        if !nose.isEmpty {
            let path = UIBezierPath()
            path.move(to: nose[0])
            for i in 1..<nose.count {
                path.addLine(to: nose[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // outerLips
        if !outerLips.isEmpty {
            let path = UIBezierPath()
            path.move(to: outerLips[0])
            for i in 1..<outerLips.count {
                path.addLine(to: outerLips[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // innerLips
        if !innerLips.isEmpty {
            let path = UIBezierPath()
            path.move(to: innerLips[0])
            for i in 1..<innerLips.count {
                path.addLine(to: innerLips[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // Face contour
        if !faceContour.isEmpty {
            let path = UIBezierPath()
            path.move(to: faceContour[0])
            for i in 1..<faceContour.count {
                path.addLine(to: faceContour[i])
            }
            createShapeLayer().path = path.cgPath
        }
        
        // Left pupil
        if !leftPupil.isEmpty {
            let path = UIBezierPath()
            path.move(to: leftPupil[0])
            for i in 1..<leftPupil.count {
                path.addLine(to: leftPupil[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        // right pupil
        if !rightPupil.isEmpty {
            let path = UIBezierPath()
            path.move(to: rightPupil[0])
            for i in 1..<rightPupil.count {
                path.addLine(to: rightPupil[i])
            }
            path.close()
            createShapeLayer().path = path.cgPath
        }
        
        DispatchQueue.main.async {
            self.view?.setNeedsDisplay()  // Now display them
        }
    }
}



