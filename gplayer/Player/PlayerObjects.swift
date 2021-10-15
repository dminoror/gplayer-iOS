//
//  PlayerObjects.swift
//  FPlayer
//
//  Created by DoubleLight on 2020/3/20.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
/*
protocol PlayableItem : NSObject {
    var identify: String { get set }
    var name: String? { get set }
    var playURL: URL? { get }
}


class fpPlayitem: NSObject, Codable, PlayableItem {
    
    static let head = "D:\\OST"
    
    var path: String?
    var gdID: String?
    private var _name: String?
    
    var identify: String {
        get {
            return gdID!
        }
        set {
            gdID = newValue
        }
    }
    var name: String? {
        get {
            if let name = _name {
                return name
            }
            else {
                return folders!.last!
            }
        }
        set {
            _name = newValue
        }
    }
    
    var playURL: URL? {
        get {
            return URL(string: "https://www.googleapis.com/drive/v3/files/\(gdID!)?alt=media")
        }
    }
    
    var folders: [String]? {
        get {
            guard var path = path else { return nil}
            path = path.replacingOccurrences(of: fpPlayitem.head, with: "")
            let folders = path.components(separatedBy: "\\").filter { (folder) -> Bool in
                return folder.count > 0
            }
            _name = folders.last
            return folders
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case path, gdID
    }
    required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try? container.decode(String.self, forKey: .path)
        self.gdID = try? container.decode(String.self, forKey: .gdID)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(gdID, forKey: .gdID)
    }
}
class fpPlaylist: NSObject, Codable {
    
    var name: String?
    var list: [fpPlayitem]?
    
    enum CodingKeys: String, CodingKey {
        case name, list
    }
    required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try? container.decode(String.self, forKey: .name)
        self.list = try? container.decode([fpPlayitem].self, forKey: .list)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(list, forKey: .list)
    }
}
*/
