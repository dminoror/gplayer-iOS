//
//  AppFlowCoordinator.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/3.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

class AppFlowCoordinator {
    
    var rootNavigation: UINavigationController
    var tabbarPage: TabbarPage?
    var playlistsNavigation: UINavigationController?
    var driveNavigation: UINavigationController?
    
    init(navigationController: UINavigationController) {
        self.rootNavigation = navigationController
        //self.rootNavigation.navigationBar.isTranslucent = false
        UINavigationBar.appearance().isTranslucent = false
    }
    
    func start() {
        let tabbarPage = makeTabbar()
        self.rootNavigation.pushViewController(tabbarPage, animated: false)
        self.tabbarPage = tabbarPage
        
        let miniPlayer = makeMiniPlayer()
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        tabbarPage.view.addSubview(miniPlayer)
        tabbarPage.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[miniPlayer]|", options: .directionLeadingToTrailing, metrics: nil, views: ["miniPlayer" : miniPlayer]))
        tabbarPage.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[miniPlayer(64)]-\(tabbarPage.tabBar.frame.height + UIScreen.safeArea.bottom)-|", options: .directionLeadingToTrailing, metrics: nil, views: ["miniPlayer" : miniPlayer]))
    }
    
    func makeTabbar() -> TabbarPage {
        let tabbarPage = TabbarPage()
        
        let page1 = makePlaylistNavigation()
        tabbarPage.addChild(page1)
        page1.tabBarItem.title = NSLocalizedString("tabbar_item_playlists", comment: "playlists")
        page1.tabBarItem.image = UIImage(systemName: "music.note.list")?.resizeImage(width: 28)
        
        let page2 = makeDriveNavigation()
        tabbarPage.addChild(page2)
        page2.tabBarItem.title = "drive"
        var image = UIImage(named: "googleDrive")
        image = image?.resizeImage(width: 28)
        page2.tabBarItem.image = image
        
        return tabbarPage
    }
    
    func makeMiniPlayer() -> MiniPlayerView {
        let viewModel = MiniPlayerViewModel(closures: MiniPlayerViewModelClosures(showPlayerPage: { [weak self] in
            let page = self?.makePlayerPage()
            self?.rootNavigation.present(page!, animated: true, completion: nil)
        }))
        let view = MiniPlayerView.create(viewModel: viewModel)
        return view
    }
    
    func makePlayerPage() -> PlayerPage {
        let viewModel = PlayerViewModel(closures: nil)
        let page = PlayerPage.create(viewModel: viewModel)
        viewModel.closures = PlayerViewModelClosures(closePlayerPage: { [weak page] in
            page?.dismiss(animated: true, completion: nil)
        })
        return page
    }
    
    func makeDriveNavigation() -> UINavigationController {
        let rootPage = makeDriveHomePage()
        let navigationController = UINavigationController(rootViewController: rootPage)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        driveNavigation = navigationController
        return navigationController
    }
    
    func makeDriveHomePage() -> DriveHomePage {
        let closures = DriveHomeViewModelClosures { [weak self] (user, parent) in
            let page = self?.makeGoogleDrivePage(user: user, parent: parent)
            self?.driveNavigation?.pushViewController(page!, animated: true)
        }
        let viewModel = DriveHomeViewModel(closures: closures)
        let page = DriveHomePage.create(viewModel: viewModel)
        return page
    }
    
    func makeGoogleDrivePage(user: GIDGoogleUser, parent: GTLRDrive_File) -> GoogleDrivePage {
        let closures = GoogleDriveViewModelClosures(showGDPage: { [weak self] (parent) in
            let page = self?.makeGoogleDrivePage(user: user, parent: parent)
            self?.driveNavigation?.pushViewController(page!, animated: true)
            }, popSelf: { [weak self] in
                self?.driveNavigation?.popViewController(animated: true)
            }, popToRoot: { [weak self] in
                self?.driveNavigation?.popToRootViewController(animated: true)
            }, presentSelectPlaylists: { [weak self] okClosure, cancelClosure in
                let page = self?.makeSelectPlaylistsPage(okClosure: okClosure, cancelClosure: cancelClosure)
                self?.driveNavigation?.present(page!, animated: true, completion: nil)
        })
        let viewModel = GoogleDriveViewModel(closures: closures, user: user, parent: parent)
        let page = GoogleDrivePage.create(viewModel: viewModel)
        return page
    }
    
    func makeSelectPlaylistsPage(okClosure: (([gpPlaylist]) -> Void)?, cancelClosure: (() -> Void)?) -> UINavigationController {
        let viewModel = SelectPlaylistsViewModel(okClosure: okClosure, cancelClosure: cancelClosure)
        let page = SelectPlaylistsPage.create(viewModel: viewModel)
        let navi = UINavigationController(rootViewController: page)
        viewModel.closures = SelectPlaylistsViewModelClosures(dismiss: { [weak navi] in
            navi?.dismiss(animated: true, completion: nil)
        })
        return navi
    }
    
    func makePlaylistNavigation() -> UINavigationController {
        let rootPage = makePlaylistsPage()
        let navigationController = UINavigationController(rootViewController: rootPage)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        playlistsNavigation = navigationController
        return navigationController
    }
    
    func makePlaylistsPage() -> PlaylistsPage {
        let playlistsClosures = PlaylistsViewModelClosures(showPlaylistPage: { [weak self] (config, index) in
            let page = self?.makePlaylistPage(config: config, playlistIndex: index)
            self?.playlistsNavigation?.pushViewController(page!, animated: true)
            }, gotoDriveHome: { [weak self] in
                self?.tabbarPage?.selectedIndex = 1
        })
        let playlistsViewModel = PlaylistsViewModel(closures: playlistsClosures)
        let playlistsPage = PlaylistsPage.create(viewModel: playlistsViewModel)
        return playlistsPage
    }
    
    func makePlaylistPage(config: gpConfigModel, playlistIndex: Int) -> PlaylistPage {
        let closures = PlaylistViewModelClosures()
        let viewModel = PlaylistViewModel(closures: closures, config: config, playlistIndex: playlistIndex)
        let page = PlaylistPage.create(viewModel: viewModel)
        return page
    }
}
