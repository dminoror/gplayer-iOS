//
//  PlaylistsPage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/3.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class PlaylistsPage: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableView: UITableView?
    var loadingView: UIActivityIndicatorView?
    var editingList: [gpPlaylist]?
    
    private var viewModel: PlaylistsViewModel!
    
    static func create(viewModel: PlaylistsViewModel) -> PlaylistsPage {
        let page = PlaylistsPage()
        page.viewModel = viewModel
        return page
    }
    
    override func loadView() {
        super.loadView()
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        self.view.addSubview(tableView)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[tableView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["tableView" : tableView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["tableView" : tableView]))
        self.tableView = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let tabbarHeight = self.tabBarController?.tabBar.frame.height {
            self.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: tabbarHeight, right: 0)
        }
        viewModel.viewDidLoad()
    }
    
    private func bind(viewModel: PlaylistsViewModel) {
        viewModel.gpConfig.didSet(observer: self, observerBlock: { [weak self] (config) in
            self?.tableView?.reloadData()
        })
        viewModel.loading.didSet(observer: self) { [weak self] (loading) in
            if (loading) {
                self?.showLoading()
            }
            else {
                self?.stopLoading()
            }
        }
        viewModel.editing.didSet(observer: self) { [weak self] (editing) in
            self?.tableView?.isEditing = editing
            if (editing) {
                self?.setupEditingNavigationItem()
                self?.editingList = viewModel.gpConfig.value?.playlists
            }
            else {
                self?.setupNavigationItem()
                self?.editingList = nil
                self?.tableView?.reloadData()
            }
        }
        viewModel.showAlert.willSet(observer: self) { [weak self] (newValue, oldValue) in
            if let alert = newValue {
                self?.showAlert(content: alert)
            }
        }
    }
    func unbind() {
        viewModel.gpConfig.remove(observer: self)
        viewModel.loading.remove(observer: self)
        viewModel.editing.remove(observer: self)
        viewModel.showAlert.remove(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
        self.setTabbarNavigationTitle(title: NSLocalizedString("tabbar_item_playlists", comment: "playlists"))
        bind(viewModel: viewModel)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear(currentViewController: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unbind()
    }
    
    func setupNavigationItem() {
        let rightButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "pencil", color: .text), style: .done, target: self, action: #selector(tabbarNavigationEdit_Clicked))
        self.navigationController?.tabBarController?.navigationItem.rightBarButtonItem = rightButton
        let leftButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "plus", color: .text), style: .done, target: self, action: #selector(tabbarNavigationPlus_Clicked))
        self.navigationController?.tabBarController?.navigationItem.leftBarButtonItem = leftButton
    }
    func setupEditingNavigationItem() {
        let rightButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "checkmark", color: .text), style: .done, target: self, action: #selector(tabbarNavigationEdited_Clicked))
        self.navigationController?.tabBarController?.navigationItem.rightBarButtonItem = rightButton
        let leftButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "xmark", color: .text), style: .done, target: self, action: #selector(tabbarNavigationCancel_Clicked))
        self.navigationController?.tabBarController?.navigationItem.leftBarButtonItem = leftButton
    }
    
    @objc func tabbarNavigationPlus_Clicked() {
        let alert = UIAlertController(title: "新增播放列表", message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "確定", style: .default, handler: { [weak self, weak alert] (action) in
            guard let name = alert?.textFields?.first?.text else { return }
            self?.viewModel.didAppendPlaylist(name: name)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    @objc func tabbarNavigationEdited_Clicked() {
        viewModel.didEditing(editing: false, edited: editingList)
    }
    @objc func tabbarNavigationEdit_Clicked() {
        viewModel.didEditing(editing: true, edited: nil)
    }
    @objc func tabbarNavigationCancel_Clicked() {
        viewModel.didEditing(editing: false, edited: nil)
    }
    
// MARK: - UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (viewModel.editing.value) {
            return editingList!.count
        }
        if let number = viewModel.gpConfig.value?.playlists?.count {
            return number
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let config = viewModel.gpConfig.value {
            var cell = tableView.dequeueReusableCell(withIdentifier: "playlistCell")
            if (cell == nil) {
                cell = UITableViewCell(style: .default, reuseIdentifier: "playlistCell")
            }
            let playlist = viewModel.editing.value ? editingList![indexPath.row] : config.playlists?[indexPath.row]
            cell?.textLabel?.text = playlist?.name
            return cell!
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.didSelectItem(at: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            editingList?.remove(at: indexPath.row)
            tableView.reloadData()
        }
    }
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if let moving = editingList?.remove(at: sourceIndexPath.row) {
            editingList?.insert(moving, at: destinationIndexPath.row)
        }
    }
}
