//
//  PlaylistsViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/4.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation
import UIKit

struct PlaylistsViewModelClosures {
    let showPlaylistPage: (gpConfigModel, Int) -> Void
    let gotoDriveHome: () -> Void
}
protocol PlaylistsViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear(currentViewController: UIViewController)
    func didSelectItem(at index: Int)
    func didAppendPlaylist(name: String)
    func didEditing(editing: Bool, edited: [gpPlaylist]?)
}

protocol PlaylistsViewModelOutput {
    var gpConfig: Observable<gpConfigModel?> { get }
    var loading: Observable<Bool> { get }
    var editing: Observable<Bool> { get }
    var showAlert: Observable<ViewModelAlertContent?> { get }
}

class PlaylistsViewModel: PlaylistsViewModelInput, PlaylistsViewModelOutput {
    
    private let closures: PlaylistsViewModelClosures?
    var gpConfig: Observable<gpConfigModel?> = Observable(nil)
    var loading: Observable<Bool> = Observable(false)
    var editing: Observable<Bool> = Observable(false)
    var showAlert: Observable<ViewModelAlertContent?> = Observable(nil)
    
    init(closures: PlaylistsViewModelClosures? = nil) {
        self.closures = closures
    }
    
    func viewDidLoad() {
        loading.value = true
        gpConfigsRepository.shared.fetchCurrentConfig { [weak self] (header, error) in
            self?.loading.value = false
            if let config = header?.config {
                self?.gpConfig.value = config
            }
            if let error = error{
                let error = error as NSError
                if (error.domain.contains("com.google")) {
                    if (error.code == 404) {
                        let alert = ViewModelAlertContent(title: "找不到雲端播放列表", message: "可能被刪除了，建議立即將本地播放列表保存至雲端", options: [
                            ViewModelAlertOption(title: "知道了", type: .default, closure: nil),
                            ViewModelAlertOption(title: "前往雲端硬碟", type: .default, closure: { [weak self] in
                                self?.closures?.gotoDriveHome()
                            })
                        ])
                        self?.showAlert.value = alert
                        self?.showAlert.value = nil
                    }
                }
                else {
                    
                }
            }
        }
    }
    
    func viewWillAppear() {
        if let config = gpConfigsRepository.shared.currentConfig {
            gpConfig.value = config
        }
        editing.value = false
    }
    
    func viewDidAppear(currentViewController: UIViewController) {
        
    }
    
    func didSelectItem(at index: Int) {
        if let config = gpConfig.value,
            index < config.playlists!.count {
            self.closures?.showPlaylistPage(config, index)
        }
    }
    
    func didAppendPlaylist(name: String) {
        let playlist = gpPlaylist(name: name)
        gpConfigsRepository.shared.appendPlaylist(playlist: playlist)
        if let config = gpConfigsRepository.shared.currentConfig {
            gpConfig.value = config
        }
    }
    
    func didEditing(editing: Bool, edited: [gpPlaylist]?) {
        self.editing.value = editing
        if let edited = edited {
            gpConfigsRepository.shared.editPlaylists(playlists: edited)
            if let config = gpConfigsRepository.shared.currentConfig {
                gpConfig.value = config
            }
        }
    }
}
