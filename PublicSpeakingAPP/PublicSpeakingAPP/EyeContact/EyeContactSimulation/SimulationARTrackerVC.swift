//
//  SimulationARTrackerVC.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 14/11/25.
//

import UIKit
import ARKit
import SceneKit

protocol SimulationARTrackerDelegate: AnyObject {
    func didUpdate(event: HeadGazeEvent)
}

// 1. Pastikan protokol ARSessionDelegate ada di sini
class SimulationARTrackerVC: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    private let logInterval: TimeInterval = 1.0
    private var lastLogTime: TimeInterval = 0.0
    
    private let delegateInterval: TimeInterval = 0.5
    private var lastDelegateTime: TimeInterval = 0.0
    
    weak var delegate: SimulationARTrackerDelegate?
    private var arView: ARSCNView!
    
    // Recorder
    private let recorder = ARVideoRecorder()
    
    // Gaze Variables
    private let gazeSmoothness: Int = 30
    private let gazeLerpFactor: CGFloat = 0.1
    private let gazeSensitivity: Float = 3.0
    private var recentGazePoints: [CGPoint] = []
    private var lastLerpedGazePoint: CGPoint = .zero

    let headPitchUpThreshold: Float = 0.08
    let headPitchDownThreshold: Float = -0.08
    private let gazeThresholdVertical: CGFloat = 25.0
    
    private var latestFaceAnchor: ARFaceAnchor?
    private var gazeOrigin: CGPoint?
    private var headOriginEulerAngles: SCNVector3?
    private var screenCenter: CGPoint = .zero
    private var lastSentEvent: HeadGazeEvent? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        setupARView()
        
        // Observer
        NotificationCenter.default.addObserver(self, selector: #selector(handleStartRecording), name: NSNotification.Name("StartARRecording"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleStopRecording), name: NSNotification.Name("StopARRecording"), object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.screenCenter = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        self.lastLerpedGazePoint = self.screenCenter
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // ⚠️ BAGIAN PALING PENTING: MENYAMBUNG PIPA DATA ⚠️
        // Kalau ini tidak ada, recorder tidak akan pernah menerima gambar.
        arView.session.delegate = self
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("✅ ARSession Running & Delegate Set")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    private func setupARView() {
            arView = ARSCNView(frame: self.view.bounds)
            self.view.addSubview(arView)
            arView.alpha = 0.01
            self.view.sendSubviewToBack(arView)
            // ----------------------
            
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
    
    // --- FUNGSI UTAMA: PIPA PENYALUR GAMBAR ---
    // Fungsi ini dipanggil ARKit 60 kali per detik
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Kirim setiap frame ke recorder
        recorder.record(pixelBuffer: frame.capturedImage, timestamp: frame.timestamp)
    }
    
    // --- Handler Recording ---
    @objc private func handleStartRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "SelfieRec_\(UUID().uuidString).mp4"
        let url = tempDir.appendingPathComponent(fileName)
        
        print("🎥 ARVC: Start Recording -> \(fileName)")
        recorder.start(outputURL: url)
    }
    
    @objc private func handleStopRecording() {
        print("🎥 ARVC: Stop Recording Request...")
        recorder.stop { url in
            if let url = url {
                print("✅ ARVC: Video Berhasil Disimpan -> \(url.lastPathComponent)")
                // Kirim balik ke ViewModel
                NotificationCenter.default.post(name: NSNotification.Name("ARRecordingSaved"), object: nil, userInfo: ["url": url])
            } else {
                print("❌ ARVC: Video Gagal Disimpan (URL nil)")
                // Kirim notifikasi gagal agar ViewModel tetap lanjut evaluasi
                NotificationCenter.default.post(name: NSNotification.Name("ARRecordingSaved"), object: nil, userInfo: nil)
            }
        }
    }
    
    // --- LOGIC GAZE TRACKING (TIDAK BERUBAH) ---
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }
        let faceAnchors = frame.anchors.compactMap { $0 as? ARFaceAnchor }
        
        guard let closestFaceAnchor = faceAnchors.min(by: { $0.transform.columns.3.z < $1.transform.columns.3.z }) else {
            self.gazeOrigin = nil
            self.headOriginEulerAngles = nil
            return
        }
        guard let node = arView.node(for: closestFaceAnchor) else { return }
        
        self.latestFaceAnchor = closestFaceAnchor
        let currentHeadEulerAngles = node.eulerAngles
        let leftEyeTransform = closestFaceAnchor.leftEyeTransform
        let rightEyeTransform = closestFaceAnchor.rightEyeTransform
        let leftDir = simd_make_float3(leftEyeTransform.columns.2)
        let rightDir = simd_make_float3(rightEyeTransform.columns.2)
        let avgDir = normalize(-(leftDir + rightDir) * 0.5)
        let leftPos = simd_make_float3(leftEyeTransform.columns.3)
        let rightPos = simd_make_float3(rightEyeTransform.columns.3)
        let avgEyePos = (leftPos + rightPos) * 0.5
        let gazeOriginWorld4 = simd_mul(closestFaceAnchor.transform, simd_float4(avgEyePos, 1.0))
        let gazeDirWorld4 = simd_mul(closestFaceAnchor.transform, simd_float4(avgDir, 0.0))
        var gazeDirWorld = simd_make_float3(gazeDirWorld4.x, gazeDirWorld4.y, gazeDirWorld4.z)
        gazeDirWorld.x *= -1.0; gazeDirWorld.y *= -1.0
        gazeDirWorld = simd_normalize(gazeDirWorld)
        let gazeOriginWorld = simd_make_float3(gazeOriginWorld4.x, gazeOriginWorld4.y, gazeOriginWorld4.z)
        let gazeEndInWorld = gazeOriginWorld + (gazeDirWorld * self.gazeSensitivity)
        let projectedGazePoint = arView.projectPoint(SCNVector3(gazeEndInWorld.x, gazeEndInWorld.y, gazeEndInWorld.z))
        
        let calibratedGazePoint2D = CGPoint(
            x: CGFloat(projectedGazePoint.x),
            y: CGFloat(projectedGazePoint.y)
        )
        
        if self.gazeOrigin == nil && closestFaceAnchor.isTracked {
            if !calibratedGazePoint2D.x.isNaN && !calibratedGazePoint2D.y.isNaN {
                self.gazeOrigin = calibratedGazePoint2D
                self.headOriginEulerAngles = currentHeadEulerAngles
            }
        }
        
        var headEvent: HeadGazeEvent = .normal
        if let headOrigin = self.headOriginEulerAngles {
            let pitch = currentHeadEulerAngles.x - headOrigin.x
            if pitch < headPitchDownThreshold {
                headEvent = .headPitchDown
            } else if pitch > headPitchUpThreshold {
                headEvent = .headPitchUp
            } else {
                headEvent = .normal
            }
        }
        
        var gazeEvent: HeadGazeEvent = .normal
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
        
        let deltaY = lerpedGazePoint.y - self.screenCenter.y
        
        if deltaY < -self.gazeThresholdVertical {
            gazeEvent = .gazeUp
        } else if deltaY > self.gazeThresholdVertical {
            gazeEvent = .gazeDown
        } else {
            gazeEvent = .normal
        }

        var finalEvent: HeadGazeEvent
        if headEvent != .normal {
            finalEvent = headEvent
        } else {
            finalEvent = gazeEvent
        }
        
        if finalEvent != self.lastSentEvent || time - self.lastDelegateTime >= self.delegateInterval {
            self.lastSentEvent = finalEvent
            DispatchQueue.main.async {
                self.delegate?.didUpdate(event: finalEvent)
            }
            self.lastDelegateTime = time
        }
        
        if time - self.lastLogTime >= self.logInterval {
            self.lastLogTime = time
        }
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
