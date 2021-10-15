//
//  PlaylistsModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/4.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

class gpConfigModel: NSObject, Codable {
    var volume: Float?
    var loopMode: Int?
    var randomMode: Bool?
    var playitemIndex: Int?
    var playlistIndex: Int?
    var playlists: [gpPlaylist]?
}

class gpPlaylist: NSObject, Codable {
    var name: String?
    var list: [gpPlayitem]?
    init(name: String) {
        self.name = name
        self.list = [gpPlayitem]()
    }
}

class gpPlayitem: NSObject, Codable, PlayableItem {
    var path: String?
    var gdID: String?
    
    init(name: String, identifier: String) {
        super.init()
        path = name
        gdID = identifier
    }
    
    var identify: String? {
        get {
            return gdID
        }
    }
    var name: String? {
        get {
            return path
        }
    }
    var playURL: URL? {
        get {
            return URL(string: "https://www.googleapis.com/drive/v3/files/\(gdID!)?alt=media")
        }
    }
}
