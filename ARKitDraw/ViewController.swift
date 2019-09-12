//
//  ViewController.swift
//  ARKitDraw
//
//  Created by Joseph Paik
//  Copyright © 2019 Joseph Paik. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import ColorSlider

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var previousPoint: SCNVector3?
    var lineColor = UIColor.white
    
    var previewView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        
        sceneView.autoenablesDefaultLighting = true
        let scene = SCNScene(named: "art.scnassets/world.scn")!
        
        sceneView.scene = scene
        
        viewport = sceneView.bounds
        
        view.addSubview(previewView)
        
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        let colorSlider = ColorSlider(orientation: .vertical, previewSide: .right)
        colorSlider.frame = CGRect(x: 20, y: 280, width: 12, height: 150)
        colorSlider.addTarget(self, action: #selector(changedColor(_:)), for: .valueChanged)
        
        colorSlider.gradientView.layer.borderWidth = 2.0
        colorSlider.gradientView.layer.borderColor = UIColor.white.cgColor
        
        view.addSubview(colorSlider)
        
    }
    
    var viewport = CGRect()
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        sceneView.session.delegate = self
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        
    }
    
    @objc func changedColor(_ slider: ColorSlider) {
        lineColor = slider.color
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    var drawing = false
    var touchLocation = CGPoint()
    
    
    @objc func handlePan(recognizer:UIPanGestureRecognizer) {
        if recognizer.state == .began {
            viewport = sceneView.bounds
            drawing = true
//            touchLocation = recognizer.location(in: self.sceneView)
        } else if recognizer.state == .changed {
//            touchLocation = recognizer.location(in: self.sceneView)
//            print(touchLocation)
        } else if recognizer.state == .ended { // optional for touch up event catching
            drawing = false
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        guard let pointOfView = sceneView.pointOfView else { return }
        
        let mat = pointOfView.transform
        guard let cam = self.sceneView.session.currentFrame?.camera else { return }

        var currentPosition = unproject(touchLoc: touchLocation, modelView: cam.transform.inverse, projection: cam.projectionMatrix)
        
            if drawing {
                if let previousPoint = previousPoint {
                    
                    let lerpedPointX = lerp(0.3, min: previousPoint.x, max: currentPosition.x)
                    let lerpedPointY = lerp(0.3, min: previousPoint.y, max: currentPosition.y)
                    let lerpedPointZ = lerp(0.3, min: previousPoint.z, max: currentPosition.z)
                    
                    let newPos = SCNVector3(x: lerpedPointX, y: lerpedPointY, z: lerpedPointZ)
                    currentPosition = newPos
                    let distance = previousPoint.distance(vector: currentPosition)
                    
                    //            if distance > 0.001 {
                    let cylinder = SCNCylinder(radius: 0.001, height: CGFloat(distance))
                    let lineNode = SCNNode(geometry: cylinder)
                    lineNode.pivot = SCNMatrix4MakeTranslation(0, -1 * distance / 2.0, 0)
                    lineNode.position = previousPoint
                    lineNode.geometry?.firstMaterial?.diffuse.contents = lineColor
                    
                    let direction = currentPosition - previousPoint
                    let axis = direction.cross(vector: SCNVector3Make(0, 1, 0))
                    let angle = acosf(direction.y / direction.length())
                    
                    lineNode.rotation = SCNVector4Make(-1 * axis.x, -1 * axis.y, -1 * axis.z, angle)
                    
                    let sphere = SCNNode(geometry: SCNSphere(radius: 0.001))
                    sphere.position = currentPosition
                    sphere.geometry?.firstMaterial?.diffuse.contents = lineColor
                    sceneView.scene.rootNode.addChildNode(lineNode)
                    sceneView.scene.rootNode.addChildNode(sphere)
                    
                }
                previousPoint = currentPosition
            } else {
                previousPoint = nil
            }
        
    }
    
    func unproject(touchLoc: CGPoint, // see below for Z depth hint discussion
        modelView: float4x4,
        projection: float4x4) -> SCNVector3 {
        
        let screenPoint = float3(Float(touchLoc.x), Float(touchLoc.y), 0.5)
        let clip = (screenPoint - float3(Float(viewport.minX), Float(viewport.minY), 1.0))
            / float3(Float(viewport.width), Float(viewport.height), 1.0)
            * float3(2) - float3(1)
        // apply the reverse of the model-view-projection transform
        let inversePM = (projection * modelView).inverse
        let result = inversePM * float4(clip.y, clip.x, 0.98, 1.0)
        return SCNVector3Make(result.x, result.y, result.z) / result.w
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        
        let indices: [Int32] = [0, 1]

        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)

        return SCNGeometry(sources: [source], elements: [element])
        
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawing = true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawing = false
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }
        
        // Retain the image buffer for Vision processing.
        currentBuffer = frame.capturedImage
        
        startDetection()
    }
    
    
    var currentBuffer: CVPixelBuffer?
    
    let handDetector = HandDetector()
    
    private func startDetection() {
        // To avoid force unwrap in VNImageRequestHandler
        guard let buffer = currentBuffer else { return }
        
        handDetector.performDetection(inputBuffer: buffer) { outputBuffer, _ in
            // Here we are on a background thread
            var previewImage: UIImage?
            var normalizedFingerTip: CGPoint?
            
            defer {
                DispatchQueue.main.async {
                    self.previewView.image = previewImage
//
//                    // Release currentBuffer when finished to allow processing next frame
                    self.currentBuffer = nil
//
//                    self.touchNode.isHidden = true
//
                    guard let tipPoint = normalizedFingerTip else {
                        return
                    }
                                        
                    self.touchLocation = CGPoint(x: self.viewport.width * tipPoint.x, y: self.viewport.height * tipPoint.y)
                    
                }
            }
            
            guard let outBuffer = outputBuffer else {
                return
            }
            
            // Create UIImage from CVPixelBuffer
            previewImage = UIImage(ciImage: CIImage(cvPixelBuffer: outBuffer))
            
            normalizedFingerTip = outBuffer.searchTopPoint()
            
            
        }
    }

}
