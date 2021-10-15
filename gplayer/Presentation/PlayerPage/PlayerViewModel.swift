//
//  PlayerViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

struct PlayerViewModelClosures {
    var closePlayerPage: () -> Void
}
protocol PlayerViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func playPauseClicked()
    func nextClicked()
    func prevClicked()
    func closeClicked()
    func loopModeClicked()
    func randomModeClicked()
    func playlistClicked()
    func playitemSelected(index: Int)
    func progressSeek(time: TimeInterval)
}

protocol PlayerViewModelOutput {
    var playState: Observable<Bool> { get }
    var playEnable: Observable<Bool> { get }
    var loopMode: Observable<playerLoopMode> { get }
    var randomMode: Observable<playerRandomMode> { get }
    var metadata: Observable<PlayerPageMetadata?> { get }
    var currentTime: Observable<TimeInterval> { get }
    var totalTime: Observable<TimeInterval> { get }
    var playlist: Observable<[PlayableItem]?> { get }
    var playlistMode: Observable<Bool> { get }
    var playlistIndex: Observable<Int> { get }
}
struct PlayerPageMetadata {
    var title: String?
    var artist: String?
    var cover: UIImage?
}

class PlayerViewModel: PlayerViewModelInput, PlayerViewModelOutput {
    
    var closures: PlayerViewModelClosures?
    
    var metadata: Observable<PlayerPageMetadata?> = Observable(nil)
    var playState: Observable<Bool> = Observable(false)
    var playEnable: Observable<Bool> = Observable(false)
    var loopMode: Observable<playerLoopMode> = Observable(.none)
    var randomMode: Observable<playerRandomMode> = Observable(.none)
    var currentTime: Observable<TimeInterval> = Observable(0)
    var totalTime: Observable<TimeInterval> = Observable(0)
    var playlist: Observable<[PlayableItem]?> = Observable(nil)
    var playlistMode: Observable<Bool> = Observable(PlayerViewModel._playlistMode)
    static var _playlistMode = false
    var playlistIndex: Observable<Int> = Observable(-1)
    
    init(closures: PlayerViewModelClosures? = nil) {
        self.closures = closures
    }
    
    func setupInfo() {
        metadata.value = PlayerPageMetadata(title: PlayerCore.shared.currentTitle, artist: PlayerCore.shared.currentArtist, cover: PlayerCore.shared.currentArtwork)
        playState.value = PlayerCore.shared.playState() == .playing
        playEnable.value = PlayerCore.shared.playState() == .playing || PlayerCore.shared.playState() == .pause
        loopMode.value = PlayerCore.shared.loopMode
        randomMode.value = PlayerCore.shared.randomMode
        if let currentTime = PlayerCore.shared.currentTime(){
            self.currentTime.value = currentTime
        }
        if let totalTime = PlayerCore.shared.totalTime() {
            self.totalTime.value = totalTime
        }
        playlist.value = PlayerCore.shared.playlist
        playlistIndex.value = PlayerCore.shared.currentPlayableIndex
    }
    
    func viewDidLoad() {
        
    }
    
    func viewDidAppear() {
        
    }
    
    func viewWillAppear() {
        setupInfo()
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlayerItemChanged), name: NSNotification.Name("playerPlayerItemChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerGotMetadata), name: NSNotification.Name("playerGotMetadata"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidPlayStateChanged), name: NSNotification.Name("playerDidPlayStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerProgressUpdate), name: NSNotification.Name("playerProgressUpdate"), object: nil)
    }
    func viewWillDisappear() {
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func playerProgressUpdate() {
        if let currentTime = PlayerCore.shared.currentTime(){
            self.currentTime.value = currentTime
        }
    }
    
    @objc
    func playerPlayerItemChanged() {
        metadata.value = nil
        playlistIndex.value = PlayerCore.shared.currentPlayableIndex
    }
    @objc
    func playerGotMetadata() {
        metadata.value = PlayerPageMetadata(title: PlayerCore.shared.currentTitle, artist: PlayerCore.shared.currentArtist, cover: PlayerCore.shared.currentArtwork)
        if let totalTime = PlayerCore.shared.totalTime() {
            self.totalTime.value = totalTime
        }
    }
    @objc
    func playerDidPlayStateChanged() {
        playState.value = PlayerCore.shared.playState() == .playing
        playEnable.value = PlayerCore.shared.playState() == .playing || PlayerCore.shared.playState() == .pause
        if let totalTime = PlayerCore.shared.totalTime() {
            self.totalTime.value = totalTime
        }
    }
    
    func playPauseClicked() {
        PlayerCore.shared.switchState()
    }
    func nextClicked() {
        PlayerCore.shared.next()
    }
    func prevClicked() {
        PlayerCore.shared.prev()
    }
    func loopModeClicked() {
        PlayerCore.shared.switchLoop()
        loopMode.value = PlayerCore.shared.loopMode
    }
    func randomModeClicked() {
        PlayerCore.shared.switchRandom()
        randomMode.value = PlayerCore.shared.randomMode
    }
    func closeClicked() {
        closures?.closePlayerPage()
    }
    func playlistClicked() {
        PlayerViewModel._playlistMode.toggle()
        playlistMode.value = PlayerViewModel._playlistMode
    }
    func playitemSelected(index: Int) {
        PlayerCore.shared.playWithIndex(index: index)
    }
    func progressSeek(time: TimeInterval) {
        PlayerCore.shared.seek(time: time)
    }
}

