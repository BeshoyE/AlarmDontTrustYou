//
//  QRScanningService.swift
//  alarmAppNew
//
//  Created by Claude Code on 9/6/25.
//  QR scanning service implementation
//

import Foundation
import AVFoundation

// Service implementation using existing QRScannerView infrastructure
class QRScanningService: QRScanning {
    private let permissionService: PermissionServiceProtocol
    private var continuation: AsyncStream<String>.Continuation?
    private var isScanning = false
    
    init(permissionService: PermissionServiceProtocol) {
        self.permissionService = permissionService
    }
    
    func startScanning() async throws {
        guard !isScanning else { return }
        
        // Check/request camera permission
        let status = await permissionService.requestCameraPermission()
        guard status == .authorized else {
            throw QRScanningError.permissionDenied
        }
        
        isScanning = true
    }
    
    func stopScanning() {
        isScanning = false
        continuation?.finish()
        continuation = nil
    }
    
    func scanResultStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    // Called by QRScannerView when scan completes
    func didScanQR(_ payload: String) {
        guard isScanning else { return }
        continuation?.yield(payload)
    }
}

enum QRScanningError: Error, LocalizedError {
    case permissionDenied
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission is required for QR scanning"
        case .scanningFailed:
            return "QR scanning failed"
        }
    }
}