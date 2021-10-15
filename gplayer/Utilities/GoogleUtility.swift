//
//  GoogleUtility.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/4.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
import GTMSessionFetcher
import GoogleSignIn
import Firebase

@objc
class GoogleUtility: NSObject, GIDSignInDelegate {
    
    @objc static let shared = GoogleUtility()
    
    let service = GTLRDriveService()
    @objc var currentUser: GIDGoogleUser?
    @objc var currentToken: String? {
        get {
            return currentUser?.authentication.accessToken
        }
    }
    
    var signInClosure: ((Error?) -> Void)?
    
    var logedUsers: [GIDGoogleUser]!
    
    override init() {
        FirebaseApp.configure()
        GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
        super.init()
        restoreLogedUsers()
    }
    
    var signed: Bool {
        get {
            if let hasPrev = GIDSignIn.sharedInstance()?.hasPreviousSignIn() {
                return hasPrev
            }
            return false
        }
    }
    
    func restoreLogedUsers() {
        if let data = UserDefaults.standard.object(forKey: "users") as? Data,
            let users = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [GIDGoogleUser] {
            logedUsers = users
        }
        else {
            logedUsers = [GIDGoogleUser]()
        }
    }
    func storeLogedUsers() {
        if let users = logedUsers,
            let data = try? NSKeyedArchiver.archivedData(withRootObject: users, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "users")
            UserDefaults.standard.synchronize()
        }
    }
    func getUser(userID: String?) -> GIDGoogleUser? {
        if let user = logedUsers.first(where: { $0.userID == userID }) {
            return user
        }
        return nil
    }
    func removeUser(userID: String) {
        if let index = logedUsers.firstIndex(where: { $0.userID == userID }) {
            logedUsers.remove(at: index)
        }
    }
    
    func signIn(currentViewController: UIViewController, result: @escaping ((Error?) -> Void)) {
        signInClosure = result
        GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().scopes = [kGTLRAuthScopeDrive]
        GIDSignIn.sharedInstance()?.presentingViewController = currentViewController
        GIDSignIn.sharedInstance()?.signIn()
    }
    
    func restoreSignIn(result: @escaping ((Error?) -> Void)) {
        signInClosure = result
        GIDSignIn.sharedInstance().delegate = self
        if ((GIDSignIn.sharedInstance()?.hasPreviousSignIn()) == true) {
            GIDSignIn.sharedInstance()?.restorePreviousSignIn()
        }
    }
    
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let userIndex = logedUsers.firstIndex(where: { (u) -> Bool in
            if (u.userID == user.userID) {
                return true
            }
            return false
        }) {
            logedUsers[userIndex] = user
        }
        else {
            logedUsers.append(user)
        }
        storeLogedUsers()
        if let closure = self.signInClosure {
            if let error = error {
                closure(error)
            }
            else {
                print((String(describing: GIDSignIn.sharedInstance()?.currentUser.authentication.accessToken)))
                service.authorizer = user.authentication.fetcherAuthorizer()
                service.shouldFetchNextPages = true
                closure(nil)
            }
            self.signInClosure = nil
        }
        GIDSignIn.sharedInstance()?.delegate = nil
    }
    
    func setupService(user: GIDGoogleUser) {
        currentUser = user
        service.authorizer = user.authentication.fetcherAuthorizer()
        service.shouldFetchNextPages = true
    }
    
    func get(fileId: String!, result: @escaping ((gpConfigModel?, Error?) -> Void)) {
        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileId)
        service.executeQuery(query) { (ticket, response, error) in
            if let gddata = response as? GTLRDataObject,
                let config = try? JSONDecoder().decode(gpConfigModel.self, from: gddata.data)
            {
                result(config, nil)
            }
            else {
                result(nil, error)
            }
        }
    }
    
    func list(rootId: String, pageToken: String?, result: @escaping (([GTLRDrive_File]?, String?, Error?) -> Void)) {
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(rootId)' in parents and trashed = false"
        query.fields = "files/name,files/id,files/appProperties,files/mimeType,nextPageToken"
        query.orderBy = "folder,name"
        query.pageToken = pageToken
        service.executeQuery(query) { (ticket, response, error) in
            if let response = response as? GTLRDrive_FileList {
                let files = response.files
                result(files, response.nextPageToken, nil)
            }
            else {
                result(nil, nil, error)
            }
        }
    }
    
    func update(configHeader: gpConfigHeader, result: @escaping ((Error?) -> Void)) {
        guard let user = getUser(userID: configHeader.gdUserID) else { return }
        setupService(user: user)
        let driveFile = GTLRDrive_File()
        driveFile.name = configHeader.name
        driveFile.mimeType = "application/json"
        guard let data = try? JSONEncoder().encode(configHeader.config) else { return }
        let parameters = GTLRUploadParameters(data: data, mimeType: "application/json")
        let query = GTLRDriveQuery_FilesUpdate.query(withObject: driveFile, fileId: configHeader.gdID!, uploadParameters: parameters)
        service.executeQuery(query) { (ticket, response, error) in
            result(error)
        }
    }
    
    func create(configHeader: gpConfigHeader, parent: String, result: @escaping ((GTLRDrive_File?, Error?) -> Void)) {
        guard let user = getUser(userID: configHeader.gdUserID) else { return }
        setupService(user: user)
        let driveFile = GTLRDrive_File()
        driveFile.name = configHeader.name
        driveFile.mimeType = "application/json"
        driveFile.appProperties = GTLRDrive_File_AppProperties()
        driveFile.appProperties?.setAdditionalProperty("1.0", forName: "version")
        driveFile.appProperties?.setAdditionalProperty("gplayer", forName: "desc")
        driveFile.parents = [parent]
        guard let data = try? JSONEncoder().encode(configHeader.config) else { return }
        let parameters = GTLRUploadParameters(data: data, mimeType: "application/json")
        let query = GTLRDriveQuery_FilesCreate.query(withObject: driveFile, uploadParameters: parameters)
        service.executeQuery(query) { (ticket, response, error) in
            result(response as? GTLRDrive_File, error)
        }
    }
}

extension GTLRDrive_File {
    var isFolder: Bool {
        if let mimeType = self.mimeType {
            if (mimeType.contains("google-apps.folder")) {
                return true
            }
        }
        return false
    }
    var isAudio: Bool {
        if let mimeType = self.mimeType {
            if (mimeType.contains("audio")) {
                return true
            }
        }
        return false
    }
    var isPlaylist: Bool {
        if let desc = self.appProperties?.additionalProperty(forName: "desc") as? String,
            desc.contains("gplayer") {
            return true
        }
        return false
    }
    var iconImage: UIImage? {
        if (self.isAudio) {
            return UIImage.systemWithColor(systemName: "music.note", color: .text)
        }
        else if (self.isFolder) {
            return UIImage.systemWithColor(systemName: "folder.fill", color: .text)
        }
        else if (self.isPlaylist) {
            return UIImage.systemWithColor(systemName: "music.note.list", color: .text)
        }
        return UIImage.systemWithColor(systemName: "doc.fill", color: .text)
    }
}
