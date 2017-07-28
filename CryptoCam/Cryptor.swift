//
//  Cryptor.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 04/07/2017.
//  Copyright © 2017 Open Lab. All rights reserved.
//

import Foundation
import IDZSwiftCommonCrypto

class Cryptor {
    static func decryptVideo(video: Video, callback:@escaping (URL?, Error?) -> ()) {
        let key = video.key!
        let iv = video.iv!
        let url = URL(string: video.url!)!.appendingPathExtension("mp4")
        
        print("Downloading file: \(url)")
        
        retrieveFile(url: url) { (data, error) in
            if let error = error {
                callback(nil, error)
            } else if let data = data {
                print("Decrypting \(data.count) bytes...")
                let decrypted = decryptBytes(key: key.hexa2Bytes, iv: iv.hexa2Bytes, data: data)
                let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent)
                
                print("Decrypted \(data.count).")
                
                do {
                    print("Writing to file: \(fileURL)")
                    try decrypted?.write(to: fileURL)
                    print("Completed.")
                    callback(fileURL, error)
                } catch {
                    callback(nil, error)
                }
            }
        }
    }
    
    static func decryptThumb(video: Video, callback:@escaping (URL?, Error?) -> ()) {
        let key = video.key!
        let iv = video.iv!
        let url = URL(string: video.url!)!.appendingPathExtension("jpg")
        
        retrieveFile(url: url) { (data, error) in
            if let error = error {
                callback(nil, error)
            } else if let data = data {
                let decrypted = decryptBytes(key: key.hexa2Bytes, iv: iv.hexa2Bytes, data: data)
                let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent)
                
                do {
                    try decrypted?.write(to: fileURL)
                    callback(fileURL, error)
                } catch {
                    callback(nil, error)
                }
            }
        }
    }
    
    static func decryptThumbBytes(video: Video, data: Data) -> Data? {
        let key = video.key!
        let iv = video.iv!
        
        return decryptBytes(key: key.hexa2Bytes, iv: iv.hexa2Bytes, data: data)
    }
    
    private static func decryptBytes(key: [UInt8], iv: [UInt8], data: Data) -> Data? {
        let cryptor = IDZSwiftCommonCrypto.Cryptor(operation: .decrypt, algorithm: .aes, mode: .CBC, padding: .NoPadding, key: key, iv: iv)
        let decrypted = cryptor.update(data: data)!.final()
        
        if let decrypted = decrypted {
            return Data(bytes: decrypted)
        } else {
            return nil
        }
    }
    
    private static func retrieveFile(url: URL, callback:@escaping (Data?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            let http = response as! HTTPURLResponse
            if let error = error, http.statusCode != 200 {
                print("Error downloading file (\(http.statusCode)): \(error)")
                callback(nil, error)
            } else {
                callback(data, nil)
            }
        }.resume()
    }
}

extension String {
    var hexa2Bytes: [UInt8] {
        let hexa = Array(characters)
        return stride(from: 0, to: characters.count, by: 2).flatMap { UInt8(String(hexa[$0..<$0.advanced(by: 2)]), radix: 16) }
    }
}
