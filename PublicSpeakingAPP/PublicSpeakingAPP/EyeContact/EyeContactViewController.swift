//
//  EyeContactViewController.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 13/11/25.
//

import UIKit
import ARKit
import SceneKit

protocol EyeContactViewControllerDelegate: AnyObject {
    func didUpdateGaze(point: CGPoint, onTarget: Bool)
}

class EyeContactViewController: UIViewController, ARSCNViewDelegate {
    
    weak var delegate: EyeContactViewControllerDelegate?
    
    private var arView: ARSCNView!
    
    private let detectionRadius: CGFloat = 30
    private let gazeSmoothness: Int = 10
    private let gazeLerpFactor: CGFloat = 0.4
    private let gazeSensitivity: Float = 1.0
    private var recentGazePoints: [CGPoint] = []
    
    private var latestFaceAnchor: ARFaceAnchor?
    private var gazeOrigin: CGPoint?
    private var screenCenter: CGPoint = .zero
    
    private var lastLerpedGazePoint: CGPoint = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        setupARView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.screenCenter = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        self.lastLerpedGazePoint = self.screenCenter
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Peringatan: Pelacakan Wajah tidak didukung.")
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        arView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    private func setupARView() {
        arView = ARSCNView(frame: self.view.bounds)
        self.view.addSubview(arView)
        self.view.sendSubviewToBack(arView)
        arView.delegate = self
        arView.backgroundColor = .clear
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: self.view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            arView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        guard let frame = arView.session.currentFrame else { return }
        let faceAnchors = frame.anchors.compactMap { $0 as? ARFaceAnchor }
        
        guard let closestFaceAnchor = faceAnchors.min(by: { $0.transform.columns.3.z < $1.transform.columns.3.z }) else {
            self.gazeOrigin = nil
            return
        }
        
        self.latestFaceAnchor = closestFaceAnchor
        
        guard let faceAnchor = self.latestFaceAnchor else { return }
        
        let leftEyeTransform = faceAnchor.leftEyeTransform
        let rightEyeTransform = faceAnchor.rightEyeTransform
        let leftDir = simd_make_float3(leftEyeTransform.columns.2)
        let rightDir = simd_make_float3(rightEyeTransform.columns.2)
        let avgDir = normalize(-(leftDir + rightDir) * 0.5)
        let leftPos = simd_make_float3(leftEyeTransform.columns.3)
        let rightPos = simd_make_float3(rightEyeTransform.columns.3)
        let avgEyePos = (leftPos + rightPos) * 0.5
        let gazeOriginWorld4 = simd_mul(faceAnchor.transform, simd_float4(avgEyePos, 1.0))
        let gazeDirWorld4 = simd_mul(faceAnchor.transform, simd_float4(avgDir, 0.0))
        var gazeDirWorld = simd_make_float3(gazeDirWorld4.x, gazeDirWorld4.y, gazeDirWorld4.z)
        gazeDirWorld.x *= -1.0
        gazeDirWorld.y *= -1.0
        gazeDirWorld = simd_normalize(gazeDirWorld)
        let gazeOriginWorld = simd_make_float3(gazeOriginWorld4.x, gazeOriginWorld4.y, gazeOriginWorld4.z)
        let gazeEndInWorld = gazeOriginWorld + (gazeDirWorld * self.gazeSensitivity)
        let projectedGazePoint = arView.projectPoint(SCNVector3(gazeEndInWorld.x, gazeEndInWorld.y, gazeEndInWorld.z))
        
        let calibratedGazePoint2D = CGPoint(
            x: CGFloat(projectedGazePoint.x),
            y: CGFloat(projectedGazePoint.y)
        )
        
        if self.gazeOrigin == nil && faceAnchor.isTracked {
            if !calibratedGazePoint2D.x.isNaN && !calibratedGazePoint2D.y.isNaN {
                print("===> SISTEM DIKALIBRASI (ZEROED) <===")
                self.gazeOrigin = calibratedGazePoint2D
            }
        }
        
        var finalGazePoint: CGPoint = self.screenCenter
        if let gazeOrigin = self.gazeOrigin {
            guard !calibratedGazePoint2D.x.isNaN && !calibratedGazePoint2D.y.isNaN else { return }
            let deltaX = calibratedGazePoint2D.x - gazeOrigin.x
            let deltaY = calibratedGazePoint2D.y - gazeOrigin.y
            finalGazePoint = CGPoint(x: self.screenCenter.x + deltaX, y: self.screenCenter.y + deltaY)
        }

        self.recentGazePoints.append(finalGazePoint)
        if self.recentGazePoints.count > self.gazeSmoothness {
            self.recentGazePoints.removeFirst()
        }
        let targetGazePoint = self.averagePoint(from: self.recentGazePoints)
        let currentGazePoint = self.lastLerpedGazePoint
        
        let newX = currentGazePoint.x + (targetGazePoint.x - currentGazePoint.x) * self.gazeLerpFactor
        let newY = currentGazePoint.y + (targetGazePoint.y - currentGazePoint.y) * self.gazeLerpFactor
        let lerpedGazePoint = CGPoint(x: newX, y: newY)
        
        self.lastLerpedGazePoint = lerpedGazePoint
        let dist = self.distance(from: lerpedGazePoint, to: self.screenCenter)
        let isGazeOnTarget = dist < self.detectionRadius
        
        DispatchQueue.main.async {
            self.delegate?.didUpdateGaze(point: lerpedGazePoint, onTarget: isGazeOnTarget)
        }
    }
    func resetCalibration() {
        print("===> KALIBRASI DI-RESET (gazeOrigin = nil) <===")
        self.gazeOrigin = nil
        self.lastLerpedGazePoint = self.screenCenter
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx*dx + dy*dy)
    }
    
    private func averagePoint(from points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        for point in points {
            totalX += point.x
            totalY += point.y
        }
        return CGPoint(x: totalX / CGFloat(points.count), y: totalY / CGFloat(points.count))
    }
}
