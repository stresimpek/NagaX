//
//  ModelDownloader.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 23/10/25.
//


import Foundation

class ModelDownloader {
    static let shared = ModelDownloader()
    
    private init() {}
    
    func downloadModel(from urlString: String, fileName: String, progressCallback: @escaping (Float) -> Void) async throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelURL = documentsURL.appendingPathComponent(fileName)
        
        // Return if already downloaded
        if fileManager.fileExists(atPath: modelURL.path) {
            progressCallback(1.0)
            return modelURL
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (tempURL, response) = try await URLSession.shared.download(from: url, progressCallback: { progress in
            progressCallback(Float(progress.fractionCompleted))
        })
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        try fileManager.moveItem(at: tempURL, to: modelURL)
        return modelURL
    }
}