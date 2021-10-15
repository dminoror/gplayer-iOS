//
//  PlaylistViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

struct PlaylistViewModelClosures {
}
protocol PlaylistViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func didSelectItem(at index: Int)
    func didEditing(editing: Bool, edited: [gpPlayitem]?)
}

protocol PlaylistViewModelOutput {
    var gpConfig: Observable<gpConfigModel> { get }
    var currentPlaylist: gpPlaylist? { get }
    var playingItem: Observable<PlayableItem?> { get }
    var editing: Observable<Bool> { get }
}

class PlaylistViewModel: PlaylistViewModelInput, PlaylistViewModelOutput {
    
    private let closures: PlaylistViewModelClosures?
    var gpConfig: Observable<gpConfigModel>
    var playlistIndex: Int
    var currentPlaylist: gpPlaylist? {
        get {
            return gpConfig.value.playlists?[playlistIndex]
        }
    }
    var playingItem: Observable<PlayableItem?> = Observable(nil)
    var editing: Observable<Bool> = Observable(false)
    
    init(closures: PlaylistViewModelClosures? = nil,
         config: gpConfigModel,
         playlistIndex: Int) {
        self.closures = closures
        self.gpConfig = Observable(config)
        self.playlistIndex = playlistIndex
    }
    
    func viewDidLoad() {
    }
    
    func viewWillAppear() {
        playingItem.value = PlayerCore.shared.currentPlayableItem
        editing.value = false
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlayerItemChanged), name: NSNotification.Name("playerPlayerItemChanged"), object: nil)
    }
    func viewDidAppear() {
    }
    
    func viewWillDisappear() {
        NotificationCenter.default.removeObserver(self)
    }
    
    func didSelectItem(at index: Int) {
        PlayerCore.shared.playWithPlayitems(playitems: currentPlaylist?.list, index: index)
    }
    
    @objc func playerPlayerItemChanged() {
        playingItem.value = PlayerCore.shared.currentPlayableItem
    }
    
    func didEditing(editing: Bool, edited: [gpPlayitem]?) {
        self.editing.value = editing
        if let edited = edited,
            let playlist = currentPlaylist {
            playlist.list = edited
            gpConfigsRepository.shared.saveCurrent()
        }
    }
}

