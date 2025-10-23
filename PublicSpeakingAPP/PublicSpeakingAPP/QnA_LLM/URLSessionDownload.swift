//
//  URLSessionDownload.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 23/10/25.
//

import Foundation

extension URLSession {
    func download(from url: URL, progressCallback: @escaping (Progress) -> Void) async throws -> (URL, URLResponse) {
        let progress = Progress(totalUnitCount: 100)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                
                continuation.resume(returning: (tempURL, response))
            }
            
            let observation = task.progress.observe(\.fractionCompleted) { taskProgress, _ in
                progress.completedUnitCount = Int64(taskProgress.fractionCompleted * 100)
                progressCallback(progress)
            }
            
            task.resume()
        }
    }
}
