//
//  Globals.swift
//  Dashphone
//
//  Created by Larry Li on 8/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
import UIKit
import Foundation


var sys: SystemManager!


/////////////////////////////////////////////////////////////////////////
//  UIImageView - extension to pull web images
/////////////////////////////////////////////////////////////////////////
extension UIImageView {
    func downloaded(from url: URL, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
             //   let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
              //  let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
            else {
                return
            }
            DispatchQueue.main.async() {
                self.image = image
            }
        }.resume()
    }
    
    func downloaded(from link: String, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloaded(from: url, contentMode: mode)
    }
}

/////////////////////////////////////////////////////////////////////////
//  UIViewController, UIApplication - extension to to support getting
//  the topMostViewController required by SystemManager
/////////////////////////////////////////////////////////////////////////
extension UIViewController {
    func topMostViewController() -> UIViewController {
        
        if let presented = self.presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        
        return self
    }
}

extension UIApplication {
    func topMostViewController() -> UIViewController? {
        return self.keyWindow?.rootViewController?.topMostViewController()
    }
}


///////////////////////////////////////////////////////////////////////////
// Add rotation to UIImage
///////////////////////////////////////////////////////////////////////////
extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        var offset : CGFloat = 0.0
        
        if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft{
            offset = 3.0*CGFloat.pi/2.0
        }
        else if UIDevice.current.orientation == UIDeviceOrientation.landscapeRight{
            offset = CGFloat.pi/2.0
        }
        else if UIDevice.current.orientation == UIDeviceOrientation.portraitUpsideDown {
            offset = 0.0
        }
        else if UIDevice.current.orientation == UIDeviceOrientation.portrait {
            offset = 0.0
        }
        
        let cgImage = self.cgImage!
        let LARGEST_SIZE = CGFloat(max(self.size.width, self.size.height))
        let context = CGContext.init(data: nil, width:Int(LARGEST_SIZE), height:Int(LARGEST_SIZE), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: cgImage.bitmapInfo.rawValue)!
        
        var drawRect = CGRect.zero
        drawRect.size = self.size
        let drawOrigin = CGPoint(x: (LARGEST_SIZE - self.size.width) * 0.5,y: (LARGEST_SIZE - self.size.height) * 0.5)
        drawRect.origin = drawOrigin
        var tf = CGAffineTransform.identity
        tf = tf.translatedBy(x: LARGEST_SIZE * 0.5, y: LARGEST_SIZE * 0.5)
        tf = tf.rotated(by: CGFloat(radians)+offset)
        tf = tf.translatedBy(x: LARGEST_SIZE * -0.5, y: LARGEST_SIZE * -0.5)
        context.concatenate(tf)
        context.draw(cgImage, in: drawRect)
        var rotatedImage = context.makeImage()!
        drawRect = drawRect.applying(tf)
        rotatedImage = rotatedImage.cropping(to: drawRect)!
        let resultImage = UIImage(cgImage: rotatedImage)
        return resultImage
    }
    
    func resize(_ newSize: CGSize) -> UIImage {
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x:0, y:0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

}

///////////////////////////////////////////////////////////////////////////
// Extend StringProtocol to handle additional string indexing function
// needed by CommandDispatch
///////////////////////////////////////////////////////////////////////////
extension StringProtocol {
    func index(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    func endIndex(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.upperBound
    }
    func indexes(of string: Self, options: String.CompareOptions = []) -> [Index] {
        var result: [Index] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...].range(of: string, options: options) {
                result.append(range.lowerBound)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
    func ranges(of string: Self, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...].range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
    func residual(of text: String) -> (Bool, String) {
        var residual = String(self)
        if residual.contains(text), let endIndex = residual.endIndex(of: text) {
            let range = self.startIndex ..< endIndex
            residual.removeSubrange(range)
            return (true, residual)
        }
        return (false, residual)
    }
    
    func filterEmailChar() -> String {
        let okayChars : Set<Character> =
            Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890-_@.")
        return String(self.filter {okayChars.contains($0) })
    }

}
