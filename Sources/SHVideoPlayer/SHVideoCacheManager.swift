//
//  CacheManager.swift
//  SHVideoPlayer
//
//  Created by Sahib Hussain on 01/09/23.
//

import Foundation
import AVFoundation

public class SHVideoCacheManager {
    
    public static let shared = SHVideoCacheManager()
    public static var DEFAULT_CACHED_VIDEO_LIMIT = 10
    
    private var assets: [Any] = []
    
    private init() {}
    
    public func addAsset(for url: URL, asset: AVAsset) {
        
        var check = false
        for assetDict in assets {
            if let _ = (assetDict as? [String: Any])?[url.absoluteString] as? AVAsset {
                print("asset already in cache")
                check = true
                break
            }
        }
        
        if check { return }
        
        let assetDict = [url.absoluteString: asset] as [String: Any]
        assets.append(assetDict)

        if assets.count > SHVideoCacheManager.DEFAULT_CACHED_VIDEO_LIMIT {
            let count = assets.count - SHVideoCacheManager.DEFAULT_CACHED_VIDEO_LIMIT
            assets.removeFirst(count)
        }
        
    }
    
    public func fetchAsset(for url: URL) -> AVAsset? {
        
        var asset: AVAsset?
        for assetDict in assets {
            if let localAsset = (assetDict as? [String: Any])?[url.absoluteString] as? AVAsset {
                asset = localAsset
                break
            }
        }
        
        return asset
        
    }
    
}
