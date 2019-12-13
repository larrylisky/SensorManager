//
//  ViewController.swift
//  PhoneSensorManager
//
//  Created by Larry Li on 12/11/19.
//  Copyright © 2019 e-motion.ai. All rights reserved.
//
//
import UIKit
import Charts
import SceneKit
import Euclid
import CoreMotion
import Foundation


class ViewController: UIViewController {

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var graphPickView: UIPickerView!
    @IBOutlet weak var exportFileName: UITextField!
    @IBOutlet weak var recordButton: UIButton!
    
    // Reference frames display params
    var scene = SCNScene()
    var cameraNode = SCNNode()
    var geometry : SCNGeometry!
    var phoneRefFrameNode : SCNNode!
    var earthRefFrameNode : SCNNode!
    var carRefFrameNode : SCNNode!
    var phoneRefFrame : Mesh!
    var earthRefFrame : Mesh!
    var carRefFrame : Mesh!
    let sensor = SensorManager()

    // UI params
    var hideRefFrameView = false
    var defaultColor : UIColor!
    var graphIndex : Int = 0
    var pickerData = [
        "Reference frames",
        "Acceleration",
        "Speed"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recordButton.setTitle("Record", for: .normal)
        defaultColor = recordButton.titleColor(for: .normal)
        
        // Set up graph picker
        graphPickView.delegate = self
        graphPickView.dataSource = self
        
        // Setup reference frame display
        if !hideRefFrameView {
            setupRefFrameView()
        }
        
        // Setup periodic timer task
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(periodic), userInfo: nil, repeats: true)
    }
    
    @IBAction func onClearPressed(_ sender: Any) {
    }
    
    @IBAction func onExportPressed(_ sender: Any) {
    }
    
    @IBAction func onRecordToggled(_ sender: Any) {
        if recordButton.titleLabel?.text == "Record" {
            recordButton.setTitleColor(UIColor.red, for: .normal)
            recordButton.setTitle("Stop", for: .normal)
        }
        else {
            recordButton.setTitleColor(defaultColor, for: .normal)
            recordButton.setTitle("Record", for: .normal)
        }
    }
    
    func setupRefFrameView() {
        // Setup scene and camera
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3.0)
        
        // Create ref frames
        phoneRefFrame = refFrame(size: 2.0, alpha: 0.2)
        earthRefFrame = refFrame(size: 2.0, alpha: 0.6)
        carRefFrame = refFrame(size: 2.0, alpha: 1.0)

        // Add phone ref frame
        geometry = SCNGeometry(phoneRefFrame) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        phoneRefFrameNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(phoneRefFrameNode)

        // Add earth ref frame
        geometry = SCNGeometry(earthRefFrame) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        earthRefFrameNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(earthRefFrameNode)

        // Add car ref frame
        geometry = SCNGeometry(carRefFrame) {
            let material = SCNMaterial()
            material.diffuse.contents = $0 as? UIColor
            return material
        }
        carRefFrameNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(carRefFrameNode)
        
        // configure the SCNView
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = false
        sceneView.backgroundColor = .white
    }
    
    
    func drawRefFrame(r: CMRotationMatrix) {
        if graphIndex == 0 || graphIndex == 2 {
            let arg = 1 + r.m11 + r.m22 + r.m33
            if arg > 0.0000001 {
                let qw = sqrt(arg)/2
                let qx = (r.m32 - r.m23) / (4*qw)
                let qy = (r.m13 - r.m31) / (4*qw)
                let qz = (r.m21 - r.m12) / (4*qw)
                earthRefFrameNode.orientation = SCNQuaternion(qx, qy, qz, qw)
            }
        }
    }
    
    
    @objc func periodic() {
        if !sceneView.isHidden {
            updateScene()
        }
    }

    
    func updateScene() {
        let course = sensor.data.course
        var RotationCP : CMRotationMatrix
        let RotationGP = sensor.rotationMatrix
        
        SCNTransaction.begin()
        drawRefFrame(r: RotationGP)
        if course >= 0  {
            let theta = -course / 180.0 * Double.pi
            let c = cos(theta)
            let s = sin(theta)
            let RotationGC = CMRotationMatrix(m11: c, m12:-s, m13: 0,
                                              m21: s, m22: c, m23: 0,
                                              m31: 0, m32: 0, m33: 1)
            RotationCP = RotationGP * RotationGC
            drawRefFrame(r: RotationCP)
        }
        SCNTransaction.commit()
    }
    
    func arrow(length: Double, color: UIColor) -> Mesh {
        let tip = Mesh.cone(radius:0.1, height:0.4, material: color)
        let rod = Mesh.cylinder(radius: 0.05, height: length, material: color)
        let mesh = rod.merge(tip.translated(by: Vector(0.0, length/2.0, 0.0) ))
        return mesh
    }
    
    
    func refFrame(size: Double, alpha: Double)-> Mesh {
        let axisX = arrow(length: size, color: UIColor(red: 1, green: 0, blue: 0, alpha: CGFloat(alpha))).rotZ(deg: 90)
        let axisY = arrow(length: size, color: UIColor(red: 0, green: 1, blue: 0, alpha: CGFloat(alpha)))
        let axisZ = arrow(length: size, color: UIColor(red: 0, green: 0, blue: 1, alpha: CGFloat(alpha))).rotX(deg: -90)
        return axisX.merge(axisY.merge(axisZ))
    }
}

// UIPickerViewDelegate, UIPickerViewDataSource extension
extension ViewController : UIPickerViewDelegate, UIPickerViewDataSource {
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    // The data to return fopr the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    // Capture the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        graphIndex = row
        sceneView.isHidden = (graphIndex != 0)
    }
}
