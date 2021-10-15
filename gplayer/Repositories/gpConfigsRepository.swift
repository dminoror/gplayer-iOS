//
//  gPlaylistRepository.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/18.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation
import GoogleSignIn

class gpConfigHeader: Codable {
    var name: String?
    var gdID: String?
    var gdUserID: String?
    var config: gpConfigModel?
    var remoteSaved: Bool
    init(name: String, gdID: String, gdUserID: String) {
        self.name = name
        self.gdID = gdID
        self.gdUserID = gdUserID
        self.remoteSaved = true
    }
}

class gpConfigsRepository {
    
    static let shared: gpConfigsRepository = gpConfigsRepository()
    
    var configs: [gpConfigHeader] = [gpConfigHeader]() {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "gpConfigsRepository.configs.didSet"), object: nil)
        }
    }
    var currentConfigHeader: gpConfigHeader? {
        get {
            return configs.first
        }
    }
    var currentConfig: gpConfigModel? {
        get {
            return currentConfigHeader?.config
        }
    }
    var lastSelectedPlaylists: [gpPlaylist]?
    
    init() {
        readConfigs()
    }
    
    func fetchCurrentConfig(result: @escaping ((gpConfigHeader?, Error?) -> Void)) {
        if let header = currentConfigHeader {
            self.fetchConfig(header: header) { (header, error) in
                result(header, error)
            }
        }
        else {
            result(nil, NSError(domain: "gpConfigsRepository", code: -2, userInfo: ["info" : "no current config"]))
        }
    }
    
    func fetchConfig(header: gpConfigHeader, result: @escaping ((gpConfigHeader?, Error?) -> Void)) {
        if let userID = header.gdUserID,
            let user = GoogleUtility.shared.getUser(userID: userID) {
            GoogleUtility.shared.setupService(user: user)
            GoogleUtility.shared.get(fileId: header.gdID) { (config, error) in
                if let config = config {
                    header.config = config
                    result(header, nil)
                }
                else {
                    result(nil, error)
                }
            }
        }
        else {
            result(nil, NSError(domain: "gpConfigsRepository", code: -1, userInfo: ["info" : "invalid userID"]))
        }
    }
    
    func updateConfig(header: gpConfigHeader, result: @escaping ((Error?) -> Void)) {
        GoogleUtility.shared.update(configHeader: header) { (error) in
            result(error)
        }
    }
    
    func saveasConfig(name: String, parent: String, gdUserID: String, result: @escaping ((Error?) -> Void)) {
        guard let header = currentConfigHeader else { return }
        header.name = name
        header.gdUserID = gdUserID
        GoogleUtility.shared.create(configHeader: header, parent: parent) { [weak header, weak self] (file, error) in
            if let file = file {
                header?.gdID = file.identifier
                self?.writeConfigs()
            }
            result(error)
        }
    }
    
    func setNewConfig(header: gpConfigHeader) -> Bool {
        if (header.config != nil) {
            if let existIndex = configs.firstIndex(where: { $0.gdID == header.gdID }) {
                configs.remove(at: existIndex)
            }
            currentConfigHeader?.config = nil
            configs.insert(header, at: 0)
            writeConfigs()
            return true
        }
        return false
    }
    
    func readConfigs() {
        if let data = UserDefaults.standard.object(forKey: "configs") as? Data,
            let configs = try? JSONDecoder().decode([gpConfigHeader].self, from: data) {
            self.configs = configs
            for header in configs {
                if (!header.remoteSaved) {
                    updateConfig(header: header) { [weak header, weak self] (error) in
                        if (error == nil) {
                            header?.remoteSaved = true
                            self?.writeConfigs()
                        }
                    }
                }
            }
        }
    }
    func writeConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: "configs")
            UserDefaults.standard.synchronize()
        }
    }
    func appendPlaylist(playlist: gpPlaylist) {
        if let header = currentConfigHeader,
            let config = header.config {
            config.playlists?.append(playlist)
            header.remoteSaved = false
            saveEdit(header: header)
        }
    }
    func editPlaylists(playlists: [gpPlaylist]) {
        if let header = currentConfigHeader,
            let config = header.config {
            config.playlists = playlists
            header.remoteSaved = false
            saveEdit(header: header)
        }
    }
    func saveCurrent() {
        if let header = currentConfigHeader {
            saveEdit(header: header)
        }
    }
    func saveEdit(header: gpConfigHeader) {
        header.remoteSaved = false
        writeConfigs()
        updateConfig(header: header) { [weak header, weak self] (error) in
            if (error == nil) {
                header?.remoteSaved = true
                self?.writeConfigs()
            }
        }
    }
    func appendPlayitem(playlists: [gpPlaylist], playitem: gpPlayitem) {
        for playlist in playlists {
            let existItem = playlist.list?.first(where: { $0.gdID == playitem.gdID })
            if (existItem == nil) {
                playlist.list?.append(playitem)
            }
        }
        if let header = currentConfigHeader {
            saveEdit(header: header)
        }
    }
}
