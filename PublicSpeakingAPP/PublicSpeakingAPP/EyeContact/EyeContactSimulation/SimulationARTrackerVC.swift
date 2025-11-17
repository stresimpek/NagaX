//
//  SimulationARTrackerVC.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 14/11/25.
//

import UIKit
import ARKit
import SceneKit

// Tambahkan di properti kelas, misalnya di bawah 'private var lastSentEvent: HeadGazeEvent? = nil'

// Protokol untuk mengirim data kembali ke SwiftUI
protocol SimulationARTrackerDelegate: AnyObject {
    func didUpdate(event: HeadGazeEvent)
}

class SimulationARTrackerVC: UIViewController, ARSCNViewDelegate {
    
    // Pengontrol Throttling
    private let logInterval: TimeInterval = 1.0 // Kirim log/event setiap 1.0 detik
    private var lastLogTime: TimeInterval = 0.0 // Waktu terakhir log/event dikirim
    private var lastGazeLogTime: TimeInterval = 0

    // 🆕 Pengontrol Throttling DELEGATE (0.5 detik)
    private let delegateInterval: TimeInterval = 0.5
    private var lastDelegateTime: TimeInterval = 0.0
    
    weak var delegate: SimulationARTrackerDelegate?
    private var arView: ARSCNView!
    
    // MARK: - Konstanta dari Logika Anda
    
    // Sensitivitas & Smoothing
    private let gazeSmoothness: Int = 30
    private let gazeLerpFactor: CGFloat = 0.1
    private let gazeSensitivity: Float = 3.0
    private var recentGazePoints: [CGPoint] = []
    private var lastLerpedGazePoint: CGPoint = .zero

    // Threshold Kepala (Pitch/Anggukan)
    let headPitchUpThreshold: Float = 0.08     // Mendongak
    let headPitchDownThreshold: Float = -0.08  // Menunduk (Nilai asli Anda salah, harusnya negatif)
    
    // Threshold Mata (Gaze)
    private let gazeThresholdVertical: CGFloat = 25.0
    
    // Properti Status
    private var latestFaceAnchor: ARFaceAnchor?
    private var gazeOrigin: CGPoint?
    private var headOriginEulerAngles: SCNVector3?
    private var screenCenter: CGPoint = .zero
    
    private var lastSentEvent: HeadGazeEvent? = nil

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        setupARView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Titik target adalah pusat layar
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
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    private func setupARView() {
        arView = ARSCNView(frame: self.view.bounds)
        self.view.addSubview(arView)
        arView.delegate = self
        arView.backgroundColor = .clear
        // === BARIS BARU DITAMBAHKAN DI SINI ===
        arView.isHidden = true // Menyembunyikan tampilan kamera/AR, tetapi sesi tetap berjalan.
        // =======================================
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: self.view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            arView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
    }
    
    // Fungsi untuk mereset kalibrasi jika diperlukan
    func resetCalibration() {
        self.gazeOrigin = nil
        self.headOriginEulerAngles = nil
        self.lastLerpedGazePoint = self.screenCenter
    }

    // MARK: - ARSCNViewDelegate (Logika Inti)
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        // --- [1. AMBIL WAJAH TERDEKAT] ---
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
        
        // --- [2. KALKULASI GAZE (Logika Asli Anda)] ---
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
        
        // Di bagian kalibrasi
        if self.gazeOrigin == nil && closestFaceAnchor.isTracked {
            if !calibratedGazePoint2D.x.isNaN && !calibratedGazePoint2D.y.isNaN {
                
                self.gazeOrigin = calibratedGazePoint2D
                self.headOriginEulerAngles = currentHeadEulerAngles
                
            }
        }
        
        // KODE BARU (FIX)
        var headEvent: HeadGazeEvent = .normal
        // Kita hanya perlu 'if let' untuk 'headOriginEulerAngles' yang memang optional
        if let headOrigin = self.headOriginEulerAngles {
            let pitch = currentHeadEulerAngles.x - headOrigin.x
            
            // TAMBAHKAN LOG INI:
            if pitch < headPitchDownThreshold {
                headEvent = .headPitchDown
            } else if pitch > headPitchUpThreshold {
                headEvent = .headPitchUp
            } else {
                headEvent = .normal
            }
        }
        
        // --- [5. KALKULASI GAZE (MATA)] ---
        var gazeEvent: HeadGazeEvent = .normal
        var finalGazePoint: CGPoint = self.screenCenter
        
        if let gazeOrigin = self.gazeOrigin {
            guard !calibratedGazePoint2D.x.isNaN && !calibratedGazePoint2D.y.isNaN else { return }
            let deltaX = calibratedGazePoint2D.x - gazeOrigin.x
            let deltaY = calibratedGazePoint2D.y - gazeOrigin.y
            finalGazePoint = CGPoint(x: self.screenCenter.x + deltaX, y: self.screenCenter.y + deltaY)
        }
        
        // Smoothing Gaze
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
        
        // Cek Gaze Threshold
        let deltaY = lerpedGazePoint.y - self.screenCenter.y
        
        // === LOG DELTA Y SETIAP 1 DETIK ===
        let now = CACurrentMediaTime()
        if now - lastGazeLogTime >= 1.0 {
            print("⏱️ Vertical Gaze deltaY: \(deltaY)")
            lastGazeLogTime = now
        }
        
        if deltaY < -self.gazeThresholdVertical { // Lihat ke atas (Y lebih kecil)
            gazeEvent = .gazeUp
        } else if deltaY > self.gazeThresholdVertical { // Lihat ke bawah (Y lebih besar)
            gazeEvent = .gazeDown
        } else {
            gazeEvent = .normal
        }

        // --- [6. KIRIM EVENT (Prioritas: Kepala dulu, baru mata)] ---
        var finalEvent: HeadGazeEvent
        if headEvent != .normal {
            finalEvent = headEvent // Pelanggaran kepala lebih prioritas
        } else {
            finalEvent = gazeEvent // Jika kepala normal, cek pelanggaran mata
        }
        
        // 🆕 THROLTTING PENGIRIMAN DELEGATE (0.5 DETIK)
            // Kirim update ke delegate HANYA jika statusnya berubah ATAU sudah lewat 0.5 detik.
            // Jika event berubah, kirim segera. Jika tidak, kirim setiap 0.5s agar VM mendapatkan sinyal tick.
        if finalEvent != self.lastSentEvent || time - self.lastDelegateTime >= self.delegateInterval {
            
            self.lastSentEvent = finalEvent
            
            // ⚠️ Panggilan delegate HANYA terjadi di sini
            DispatchQueue.main.async { // Tetap gunakan main.async untuk delegasi ke SwiftUI VM
                self.delegate?.didUpdate(event: finalEvent)
            }
            self.lastDelegateTime = time // Perbarui waktu terakhir kirim delegate
        }
        
        // --- [7. THROTTLED LOG + EVENT PER DETIK] ---
        if time - self.lastLogTime >= self.logInterval {

            // Log kalibrasi (hanya sekali)
            if self.gazeOrigin != nil && self.lastLogTime == 0.0 {
                if let headOrigin = self.headOriginEulerAngles {
                    print("===> SIMULASI AR-TRACKER DIKALIBRASI <===")
                    print("Head Origin: x=\(headOrigin.x), y=\(headOrigin.y), z=\(headOrigin.z)")
                }
            }

            // Log pitch
            if let headOrigin = self.headOriginEulerAngles {
                let currentPitch = currentHeadEulerAngles.x - headOrigin.x
                print("Pitch: \(currentPitch) | Up: \(headPitchUpThreshold) | Down: \(headPitchDownThreshold)")

                if headEvent == .headPitchDown {
                    print("🔴 KEPALA MENUNDUK TERDETEKSI")
                } else if headEvent == .headPitchUp {
                    print("🔵 KEPALA MENDONGAK TERDETEKSI")
                }
            }

            self.lastLogTime = time
        }
    }
    
    // MARK: - Utility (Dari Kode Asli Anda)
    
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
