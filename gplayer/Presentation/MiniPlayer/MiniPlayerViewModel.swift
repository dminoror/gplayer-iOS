//
//  MiniPlayerViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/8.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

struct MiniPlayerViewModelClosures {
    let showPlayerPage: () -> Void
}

protocol MiniPlayerViewModelInput {
    func viewWillAppear()
    func viewWillDisappear()
    func didClickPlayButton()
    func didClickMiniPlayer()
}

protocol MiniPlayerViewModelOutput {
    var playState: Observable<Bool> { get }
    var playEnable: Observable<Bool> { get }
    var progress: Observable<Double> { get }
    var metadata: Observable<MiniPlayerMetadata?> { get }
    var loading: Observable<Bool> { get }
}

struct MiniPlayerMetadata {
    var title: String?
    var cover: UIImage?
}

class MiniPlayerViewModel: MiniPlayerViewModelInput, MiniPlayerViewModelOutput {
    
    private let closures: MiniPlayerViewModelClosures?
    
    var playState: Observable<Bool> = Observable(false)
    var playEnable: Observable<Bool> = Observable(false)
    var progress: Observable<Double> = Observable(0)
    var metadata: Observable<MiniPlayerMetadata?> = Observable(nil)
    var loading: Observable<Bool> = Observable(false)
    
    init(closures: MiniPlayerViewModelClosures? = nil) {
        self.closures = closures
    }
    
    func viewWillAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlayerItemChanged), name: NSNotification.Name("playerPlayerItemChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerGotMetadata), name: NSNotification.Name("playerGotMetadata"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidPlayStateChanged), name: NSNotification.Name("playerDidPlayStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerProgressUpdate), name: NSNotification.Name("playerProgressUpdate"), object: nil)
    }
    func viewWillDisappear() {
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func playerProgressUpdate() {
        progress.value = PlayerCore.shared.currentTime()! / PlayerCore.shared.totalTime()!
    }
    
    func didClickPlayButton() {
        PlayerCore.shared.switchState()
    }
    
    func didClickMiniPlayer() {
        if (PlayerCore.shared.currentPlayableItem != nil) {
            closures?.showPlayerPage()
        }
    }
    
    @objc
    func playerPlayerItemChanged() {
        metadata.value = MiniPlayerMetadata(title: PlayerCore.shared.currentTitle, cover: PlayerCore.shared.currentArtwork)
        loading.value = true
    }
    @objc
    func playerGotMetadata() {
        metadata.value = MiniPlayerMetadata(title: PlayerCore.shared.currentTitle, cover: PlayerCore.shared.currentArtwork)
    }
    @objc
    func playerDidPlayStateChanged() {
        playState.value = PlayerCore.shared.playState() == .playing
        playEnable.value = PlayerCore.shared.playState() == .playing || PlayerCore.shared.playState() == .pause
        if (loading.value && PlayerCore.shared.playState() == .playing) {
            loading.value = false
        }
    }
}

