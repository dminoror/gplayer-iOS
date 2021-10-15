//
//  DriveHomeViewModelViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation
import GoogleSignIn
import GoogleAPIClientForREST

enum DriveEntryType {
    case add
    case google(user: GIDGoogleUser)
}

struct DriveHomeViewModelClosures {
    let showGDPage: (_ user: GIDGoogleUser, _ parent: GTLRDrive_File) -> Void
}
protocol DriveHomeViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    //func didSelectEntry(entry: DriveEntryType, currentViewController: UIViewController)
    func didSelectItem(at index: Int, currentViewController: UIViewController)
}

protocol DriveHomeViewModelOutput {
}

class DriveHomeViewModel: DriveHomeViewModelInput, DriveHomeViewModelOutput {
    
    private let closures: DriveHomeViewModelClosures?
    
    var entries: Observable<[DriveEntryType]> = Observable([.add])
    
    init(closures: DriveHomeViewModelClosures? = nil) {
        self.closures = closures
        self.updateGoogleUsers()
    }
    
    func updateGoogleUsers() {
        var entries = [DriveEntryType]()
        entries.append(.add)
        for user in GoogleUtility.shared.logedUsers {
            entries.append(.google(user: user))
        }
        self.entries.value = entries
    }
    
    func viewDidLoad() {
    }
    func viewWillAppear() {
        self.updateGoogleUsers()
    }
    func viewDidAppear() {
    }
    
    func didSelectItem(at index: Int, currentViewController: UIViewController) {
        if (index >= entries.value.count) {
            return
        }
        let entry = entries.value[index]
        switch entry {
        case .add:
            GoogleUtility.shared.signIn(currentViewController: currentViewController) { [weak self] (error) in
                self?.updateGoogleUsers()
            }
        case .google(user: let user):
            GoogleUtility.shared.setupService(user: user)
            let file = GTLRDrive_File()
            file.identifier = "root"
            file.name = user.profile.name
            closures?.showGDPage(user, file)
        }
    }
}

