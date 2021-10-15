//
//  SelectPlaylistsViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

struct SelectPlaylistsViewModelClosures {
    let dismiss: () -> Void
}
protocol SelectPlaylistsViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func okClicked(selected: [IndexPath]?)
    func cancelClicked()
}

protocol SelectPlaylistsViewModelOutput {
    var config: Observable<gpConfigModel?> { get }
}

class SelectPlaylistsViewModel: SelectPlaylistsViewModelInput, SelectPlaylistsViewModelOutput {
    
    var closures: SelectPlaylistsViewModelClosures?
    private let okClosure: (([gpPlaylist]) -> Void)?
    private let cancelClosure: (() -> Void)?
    
    var config: Observable<gpConfigModel?> = Observable(nil)
    
    init(okClosure: (([gpPlaylist]) -> Void)?, cancelClosure: (() -> Void)?) {
        self.okClosure = okClosure
        self.cancelClosure = cancelClosure
    }
    
    func viewDidLoad() {
        config.value = gpConfigsRepository.shared.currentConfig
    }
    func viewWillAppear() {
        
    }
    func viewDidAppear() {
    }
    
    deinit {
        print("deinit")
    }
    
    func okClicked(selected: [IndexPath]?) {
        if let closure = okClosure,
            let selected = selected {
            var playlists = [gpPlaylist]()
            for (_, element) in selected.enumerated() {
                if let playlist = config.value?.playlists?[element.row] {
                    playlists.append(playlist)
                }
            }
            closure(playlists)
        }
        closures?.dismiss()
    }
    func cancelClicked() {
        closures?.dismiss()
    }
}

