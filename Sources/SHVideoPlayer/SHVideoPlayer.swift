//
//  SHVideoPlayer.swift
//  SHVideoPlayer
//
//  Created by Sahib Hussain on 01/09/23.
//

import UIKit
import AVFoundation
import OSLog

public extension Float {
    
    var double: Double {
        return Double(self)
    }
    
}

public extension Double {
    
    var int: Int {
        return Int(self)
    }
    
    var float: Float {
        return Float(self)
    }
    
}

public class SHVideoPlayer: UIView {
    
    private let logger = Logger(subsystem: "", category: "SHVideoPlayer")
    
    public enum State {
        
        /// None
        case none
        
        /// From the first load to get the first frame of the video
        case loading
        
        /// Playing now
        case playing
        
        /// Pause, will be called repeatedly when the buffer progress changes
        case paused(playProgress: Double, bufferProgress: Double)
        
        /// An error occurred and cannot continue playing
        case error(NSError)
    }
    
    public enum PausedReason: Int {
        
        /// Pause because the player is not visible, stateDidChanged is not called when the buffer progress changes
        case hidden
        
        /// Pause triggered by user interaction, default behavior
        case userInteraction
        
        /// Waiting for resource completion buffering
        case waitingKeepUp
    }
    
    /// Get current video status.
    public private(set) var state: State = .none {
        didSet { stateDidChanged(state: state, previous: oldValue) }
    }
    
    /// The reason the video was paused.
    public private(set) var pausedReason: PausedReason = .waitingKeepUp
    
    /// Number of replays.
    public private(set) var replayCount: Int = 0
    
    public let playerLayer = AVPlayerLayer()
    
    /// Whether the video will be automatically replayed until the end of the video playback.
    open var isAutoReplay: Bool = true
    
    /// Play to the end time.
    open var didPlayToEndTime: (() -> Void)?
    
    /// Playback status changes, such as from play to pause.
    open var stateDidChanged: ((State) -> Void)?
    
    /// Replay after playing to the end.
    open var replay: (() -> Void)?
    
    open var isMuted: Bool {
        get { return player?.isMuted ?? false }
        set { player?.isMuted = newValue }
    }
    
    /// Video volume, only for this instance.
    open var volume: Double {
        get { return player?.volume.double ?? 0 }
        set { player?.volume = newValue.float }
    }
    
    /// Played progress, value range 0-1.
    public var playProgress: Double {
        return isLoaded ? player?.playProgress ?? 0 : 0
    }
    
    /// Played length in seconds.
    public var currentDuration: Double {
        return isLoaded ? player?.currentDuration ?? 0 : 0
    }
    
    /// Buffered progress, value range 0-1.
    public var bufferProgress: Double {
        return isLoaded ? player?.bufferProgress ?? 0 : 0
    }
    
    /// Buffered length in seconds.
    public var currentBufferDuration: Double {
        return isLoaded ? player?.currentBufferDuration ?? 0 : 0
    }
    
    /// Total video duration in seconds.
    public var totalDuration: Double {
        return isLoaded ? player?.totalDuration ?? 0 : 0
    }
    
    /// The total watch time of this video, in seconds.
    public var watchDuration: Double {
        return isLoaded ? currentDuration + totalDuration * Double(replayCount) : 0
    }
    
    
    private var isLoaded = false
    private var isReplay = false
    
    
    private var playerBufferingObservation: NSKeyValueObservation?
    private var playerItemKeepUpObservation: NSKeyValueObservation?
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var playerLayerReadyForDisplayObservation: NSKeyValueObservation?
    private var playerTimeControlStatusObservation: NSKeyValueObservation?
    private var periodicObservation: Any?
    
    
    open override var contentMode: UIView.ContentMode {
        didSet {
            switch contentMode {
            case .scaleAspectFill:  playerLayer.videoGravity = .resizeAspectFill
            case .scaleAspectFit:   playerLayer.videoGravity = .resizeAspect
            default:                playerLayer.videoGravity = .resize
            }
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        guard playerLayer.superlayer == layer else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureInit()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        observe(player: nil)
        observe(playerItem: nil)
    }
    
}

// MARK: initialise player
extension SHVideoPlayer {
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var urlOfCurrentlyPlayingInPlayer: URL? {
        return ((player?.currentItem?.asset) as? AVURLAsset)?.url
    }
    
    func configureInit() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd(notification:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        layer.addSublayer(playerLayer)
        
    }
    
    func setupViews(_ url: URL) {
        
        observe(player: nil)
        observe(playerItem: nil)
        
        if let currentPlayer = self.player, url == urlOfCurrentlyPlayingInPlayer {
            logger.info("player with url already exist")
            
            currentPlayer.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            currentPlayer.currentItem?.preferredForwardBufferDuration = 1
            
            currentPlayer.automaticallyWaitsToMinimizeStalling = false
            self.player = currentPlayer
            
            observe(player: currentPlayer)
            observe(playerItem: currentPlayer.currentItem)
            return
        }
        
        var asset = AVAsset(url: url)
        if let cachedAsset = CacheManager.shared.fetchAsset(for: url) {
            logger.info("asset found in cache")
            asset = cachedAsset
        }else {
            logger.info("asset caching")
            CacheManager.shared.addAsset(for: url, asset: asset)
        }
        
        let currentItem = AVPlayerItem(asset: asset)
        currentItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        currentItem.preferredForwardBufferDuration = 1
        
        let currentPlayer = AVPlayer(playerItem: currentItem)
        currentPlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.player = currentPlayer
        self.replayCount = 0
        self.isLoaded = false
        self.pausedReason = .hidden
        self.state = .none
        
        observe(player: currentPlayer)
        observe(playerItem: currentItem)
        
    }
    
}

// MARK: manuplate player
public extension SHVideoPlayer {
    
    func play() {
        
        self.pausedReason = .waitingKeepUp
        self.player?.play()
        
    }
    
    func pause(_ reason: SHVideoPlayer.PausedReason) {
        pausedReason = reason
        player?.pause()
        
        if reason == .hidden {
            player?.seek(to: .zero)
        }
        
    }
    
    /// Replay video.
    ///
    /// - Parameter resetCount: Reset replayCount
    func replay(resetCount: Bool = false) {
        replayCount = resetCount ? 0 : replayCount + 1
        player?.seek(to: .zero)
        player?.play()
    }
    
    /// Moves the playback cursor and invokes the specified block when the seek operation has either been completed or been interrupted.
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        player?.seek(to: time) { completion?($0) }
    }
    
    
}


// MARK: observers
public extension SHVideoPlayer {
    
    func observe(playerItem: AVPlayerItem?) {
        
        guard let playerItem = playerItem else {
            playerBufferingObservation = nil
            playerItemStatusObservation = nil
            playerItemKeepUpObservation = nil
            return
        }
        
        playerBufferingObservation = playerItem.observe(\.loadedTimeRanges) { [unowned self] item, _ in
            if case .paused = self.state, self.pausedReason != .hidden {
                self.state = .paused(playProgress: self.playProgress, bufferProgress: self.bufferProgress)
            }
        }
        
        playerItemStatusObservation = playerItem.observe(\.status) { [unowned self] item, _ in
            if item.status == .failed, let error = item.error as NSError? {
                self.state = .error(error)
                logger.error("status: \(error.localizedDescription)")
            }
        }
        
        playerItemKeepUpObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp) { [unowned self] item, _ in
            if item.isPlaybackLikelyToKeepUp {
                if self.player?.rate == 0, self.pausedReason == .waitingKeepUp {
                    self.player?.play()
                }
            }
        }
    }
    
    func observe(player: AVPlayer?) {
        
        guard let player = player else {
            playerLayerReadyForDisplayObservation = nil
            playerTimeControlStatusObservation = nil
            return
        }
        
        playerLayerReadyForDisplayObservation = playerLayer.observe(\.isReadyForDisplay) { [unowned self, unowned player] playerLayer, _ in
            if playerLayer.isReadyForDisplay, player.rate > 0 {
                self.isLoaded = true
                self.state = .playing
            }
        }
        
        playerTimeControlStatusObservation = player.observe(\.timeControlStatus) { [unowned self] player, _ in
            switch player.timeControlStatus {
            case .paused:
                guard !self.isReplay else { break }
                self.state = .paused(playProgress: self.playProgress, bufferProgress: self.bufferProgress)
                if self.pausedReason == .waitingKeepUp { player.play() }
            case .waitingToPlayAtSpecifiedRate:
                break
            case .playing:
                if self.playerLayer.isReadyForDisplay, player.rate > 0 {
                    self.isLoaded = true
                    if self.playProgress == 0, self.isReplay { self.isReplay = false; break }
                    self.state = .playing
                }
            @unknown default:
                break
            }
        }
        
    }
    
    func stateDidChanged(state: State, previous: State) {
        
        guard state != previous else {
            return
        }
        
        switch state {
        case .playing, .paused: isHidden = false
        default:                isHidden = true
        }
        
        stateDidChanged?(state)
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) {
        guard (notification.object as? AVPlayerItem) == player?.currentItem else {
            return
        }
        
        didPlayToEndTime?()
        
        guard isAutoReplay, pausedReason == .waitingKeepUp else {
            return
        }
        
        isReplay = true
        
        replay?()
        replayCount += 1
        
        player?.seek(to: CMTime.zero)
        player?.play()
    }
    
}

extension SHVideoPlayer.State: Equatable {
    
    public static func == (lhs: SHVideoPlayer.State, rhs: SHVideoPlayer.State) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.loading, .loading):
            return true
        case (.playing, .playing):
            return true
        case let (.paused(p1, b1), .paused(p2, b2)):
            return (p1 == p2) && (b1 == b2)
        case let (.error(e1), .error(e2)):
            return e1 == e2
        default:
            return false
        }
    }
    
}


// MARK: AVPlayerItem Extension
public extension AVPlayerItem {
    
    var bufferProgress: Double {
        return currentBufferDuration / totalDuration
    }
    
    var currentBufferDuration: Double {
        guard let range = loadedTimeRanges.first else { return 0 }
        return Double(CMTimeGetSeconds(CMTimeRangeGetEnd(range.timeRangeValue)))
    }
    
    var currentDuration: Double {
        return Double(CMTimeGetSeconds(currentTime()))
    }
    
    var playProgress: Double {
        return currentDuration / totalDuration
    }
    
    var totalDuration: Double {
        return Double(CMTimeGetSeconds(asset.duration))
    }
    
}


public extension AVPlayer {
    
    var bufferProgress: Double {
        return currentItem?.bufferProgress ?? -1
    }
    
    var currentBufferDuration: Double {
        return currentItem?.currentBufferDuration ?? -1
    }
    
    var currentDuration: Double {
        return currentItem?.currentDuration ?? -1
    }
    
    var currentImage: UIImage? {
        guard
            let playerItem = currentItem,
            let cgImage = try? AVAssetImageGenerator(asset: playerItem.asset).copyCGImage(at: currentTime(), actualTime: nil)
            else { return nil }

        return UIImage(cgImage: cgImage)
    }
    
    var playProgress: Double {
        return currentItem?.playProgress ?? -1
    }
    
    var totalDuration: Double {
        return currentItem?.totalDuration ?? -1
    }
    
    convenience init(asset: AVURLAsset) {
        self.init(playerItem: AVPlayerItem(asset: asset))
    }
    
}
