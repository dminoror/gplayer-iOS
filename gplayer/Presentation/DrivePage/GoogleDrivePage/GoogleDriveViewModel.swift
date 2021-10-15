//
//  GoogleDriveViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation
import GoogleSignIn
import GoogleAPIClientForREST

struct GoogleDriveViewModelClosures {
    let showGDPage: (_ parent: GTLRDrive_File) -> Void
    let popSelf: () -> Void
    let popToRoot: () -> Void
    let presentSelectPlaylists: ((([gpPlaylist]) -> Void)?, (() -> Void)?) -> Void
}
protocol GoogleDriveViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func didSelectItem(at index: Int)
    func didSelectItemMore(index: Int)
    func didClickUpload(name: String)
    func didReachLoadingPage()
}

protocol GoogleDriveViewModelOutput {
    var files: Observable<[GTLRDrive_File]> { get }
    var showAlert: Observable<ViewModelAlertContent?> { get }
    var loading: Observable<Bool> { get }
    var title: Observable<String?> { get }
}

class GoogleDriveViewModel: GoogleDriveViewModelInput, GoogleDriveViewModelOutput {
    
    private let closures: GoogleDriveViewModelClosures?
    
    var parent: GTLRDrive_File!
    var user: GIDGoogleUser!
    var title: Observable<String?> = Observable(nil)
    var files: Observable<[GTLRDrive_File]> = Observable([GTLRDrive_File]())
    var showAlert: Observable<ViewModelAlertContent?> = Observable(nil)
    var loading: Observable<Bool> = Observable(false)
    var moreSheet: Observable<gpActionSheet?> = Observable(nil)
    var nextPageToken: Observable<String?> = Observable(nil)
    
    init(closures: GoogleDriveViewModelClosures? = nil, user: GIDGoogleUser, parent: GTLRDrive_File) {
        self.closures = closures
        self.parent = parent
        self.user = user
        title.value = parent.name
        fetchFolder()
    }
    
    func fetchFolder() {
        self.loading.value = true
        GoogleUtility.shared.list(rootId: parent.identifier!, pageToken: nil) { [weak self] (files, nextPageToken, error) in
            self?.loading.value = false
            //self?.nextPageToken.value = nextPageToken
            if let files = files {
                self?.files.value = files
            }
            else {
                let error = error! as NSError
                if (error.domain.contains("token")) {
                    self?.showAlert.value = ViewModelAlertContent(title: "登入已失效", message: "請重新登入該帳號", options: [ViewModelAlertOption(title: "OK", type: .default, closure: { [weak self] in
                        GoogleUtility.shared.removeUser(userID: (self?.user.userID)!)
                        self?.closures?.popToRoot()
                    })])
                }
                else {
                    self?.showAlert.value = ViewModelAlertContent(title: "錯誤", message: "請確認網路狀況後再試", options: [ViewModelAlertOption(title: "OK", type: .default, closure: {
                        self?.closures?.popSelf()
                    })])
                    self?.showAlert.value = nil
                }
            }
        }
    }
    
    func viewDidLoad() {
    }
    func viewWillAppear() {
        
    }
    func viewDidAppear() {
    }
    
    func didSelectItem(at index: Int) {
        if (index >= files.value.count) {
            return
        }
        let file = files.value[index]
        if (file.isFolder) {
            closures?.showGDPage(file)
        }
        else if (file.isAudio) {
            let playitem = gpPlayitem(name: file.name!, identifier: file.identifier!)
            PlayerCore.shared.playWithPlayitems(playitems: [playitem], index: 0)
        }
        else {
            if (file.isPlaylist) {
                showAlert.value = ViewModelAlertContent(title: "要套用這個播放設定嗎？", message: nil, options: [
                    ViewModelAlertOption(title: "取消", type: .cancel, closure: nil),
                    ViewModelAlertOption(title: "OK", type: .default, closure: { [weak self] in
                        self?.trySetConfig(file: file)
                })])
                showAlert.value = nil
            }
        }
    }
    
    func didSelectItemMore(index: Int) {
        let file = files.value[index]
        var closures: [((UIViewAnimatingPosition) -> Void)?] = []
        closures.append { [weak file] (position) in
            if position == .end,
                let file = file {
                let playitem = gpPlayitem(name: file.name!, identifier: file.identifier!)
                PlayerCore.shared.insertPlayitem(playitem: playitem)
            }
        }
        closures.append { [weak file] (position) in
            if position == .end,
                let file = file {
                let playitem = gpPlayitem(name: file.name!, identifier: file.identifier!)
                PlayerCore.shared.appendPlayitem(playitem: playitem)
            }
        }
        closures.append { [weak self] (position) in
            if position == .end {
                self?.closures?.presentSelectPlaylists({ [weak file] playlists in
                    if let file = file {
                        let playitem = gpPlayitem(name: file.name!, identifier: file.identifier!)
                        gpConfigsRepository.shared.appendPlayitem(playlists: playlists, playitem: playitem)
                    }
                    gpConfigsRepository.shared.lastSelectedPlaylists = playlists
                }, {
                    
                })
            }
        }
        var options = [
            gpActionSheetOption(title: "插入為下一首", icon: UIImage.systemWithColor(systemName: "text.insert", color: .text)),
            gpActionSheetOption(title: "加入當前播放清單", icon: UIImage.systemWithColor(systemName: "text.append", color: .text)),
            gpActionSheetOption(title: "加入播放列表", icon: UIImage.systemWithColor(systemName: "plus.rectangle", color: .text))]
        
        if let lastSelectedPlaylists = gpConfigsRepository.shared.lastSelectedPlaylists {
            let option = gpActionSheetOption(title: "加入上次選擇的播放列表", icon: UIImage.systemWithColor(systemName: "plus.rectangle.on.rectangle", color: .text))
            options.append(option)
            closures.append { [weak file] (position) in
                if position == .end,
                    let file = file {
                    let playitem = gpPlayitem(name: file.name!, identifier: file.identifier!)
                    gpConfigsRepository.shared.appendPlayitem(playlists: lastSelectedPlaylists, playitem: playitem)
                }
            }
        }
        
        let sheet = gpActionSheet(closures: closures,
                                  title: gpActionSheetOption(title: file.name, icon: file.iconImage),
                                  options: options)
        
        moreSheet.value = sheet
        moreSheet.value = nil
    }
    
    func trySetConfig(file: GTLRDrive_File) {
        let header = gpConfigHeader(name: file.name!, gdID: file.identifier!, gdUserID: user.userID)
        loading.value = true
        gpConfigsRepository.shared.fetchConfig(header: header) { [weak self] (header, error) in
            self?.loading.value = false
            if let header = header {
                let result = gpConfigsRepository.shared.setNewConfig(header: header)
                if (result) {
                    self?.showAlert.value = ViewModelAlertContent(title: "設定完成", message: nil, options: [ViewModelAlertOption(title: "OK", type: .default, closure: nil)])
                }
                else {
                    self?.showAlert.value = ViewModelAlertContent(title: "設定失敗", message: nil, options: [ViewModelAlertOption(title: "OK", type: .default, closure: nil)])
                }
            }
            else {
                self?.showAlert.value = ViewModelAlertContent(title: "設定失敗", message: nil, options: [ViewModelAlertOption(title: "OK", type: .default, closure: nil)])
            }
            self?.showAlert.value = nil
        }
    }
    
    func didClickUpload(name: String) {
        loading.value = true
        gpConfigsRepository.shared.saveasConfig(name: name, parent: parent.identifier!, gdUserID: user.userID) { [weak self] (error) in
            self?.loading.value = false
            if (error == nil) {
                self?.fetchFolder()
            }
            else {
                self?.showAlert.value = ViewModelAlertContent(title: "上傳失敗", message: "請稍後再試", options: [
                    ViewModelAlertOption(title: "OK", type: .default, closure: nil)])
                self?.showAlert.value = nil
            }
        }
    }
    
    func didReachLoadingPage() {
        /*
        GoogleUtility.shared.list(rootId: parent.identifier!, pageToken: nextPageToken.value) { [weak self] (files, nextPageToken, error) in
            self?.nextPageToken.value = nextPageToken
            if let files = files {
                self?.files.value.append(contentsOf: files)
            }
        }*/
    }
}

