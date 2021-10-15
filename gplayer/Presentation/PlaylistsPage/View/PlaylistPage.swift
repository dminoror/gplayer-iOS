//
//  PlaylistPage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class PlaylistPage: UIViewController, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    var tableView: UITableView?
    var editingList: [gpPlayitem]?
    
    private var viewModel: PlaylistViewModel!
    
    static func create(viewModel: PlaylistViewModel) -> PlaylistPage {
        let page = PlaylistPage()
        page.viewModel = viewModel
        return page
    }
    
    func updateInfo() {
        tableView?.reloadData()
        self.setTabbarNavigationTitle(title: viewModel.currentPlaylist?.name)
    }
    
    override func loadView() {
        super.loadView()
        
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        self.view.addSubview(tableView)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[tableView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["tableView" : tableView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["tableView" : tableView]))
        self.tableView = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
        bind(viewModel: viewModel)
    }
    
    private func bind(viewModel: PlaylistViewModel) {
        viewModel.gpConfig.didSet(observer: self) { [weak self] (config) in
            self?.updateInfo()
        }
        viewModel.playingItem.didSet(observer: self) { [weak self] (item) in
            self?.tableView?.reloadData()
        }
        viewModel.editing.didSet(observer: self) { [weak self] (editing) in
            self?.tableView?.isEditing = editing
            if (editing) {
                self?.setupEditingNavigationItem()
                self?.editingList = viewModel.currentPlaylist?.list
            }
            else {
                self?.setupNavigationItem()
                self?.editingList = nil
                self?.tableView?.reloadData()
            }
        }
    }
    
    private func unbind() {
        viewModel.gpConfig.remove(observer: self)
        viewModel.playingItem.remove(observer: self)
        viewModel.editing.remove(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
        self.setTabbarNavigationBack()
        bind(viewModel: viewModel)
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unbind()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
    
    func setupNavigationItem() {
        let rightButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "pencil", color: .text), style: .done, target: self, action: #selector(tabbarNavigationEdit_Clicked))
        self.navigationController?.tabBarController?.navigationItem.rightBarButtonItem = rightButton
        self.setTabbarNavigationBack()
    }
    func setupEditingNavigationItem() {
        let rightButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "checkmark", color: .text), style: .done, target: self, action: #selector(tabbarNavigationEdited_Clicked))
        self.navigationController?.tabBarController?.navigationItem.rightBarButtonItem = rightButton
        let leftButton = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "xmark", color: .text), style: .done, target: self, action: #selector(tabbarNavigationCancel_Clicked))
        self.navigationController?.tabBarController?.navigationItem.leftBarButtonItem = leftButton
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
        if let list = self.viewModel.currentPlaylist?.list {
            return list.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let list = self.viewModel.currentPlaylist?.list {
            var cell = tableView.dequeueReusableCell(withIdentifier: "playlistCell")
            if (cell == nil) {
                cell = UITableViewCell(style: .default, reuseIdentifier: "playlistCell")
                cell?.selectionStyle = .none
            }
            let playitem = viewModel.editing.value ? editingList![indexPath.row] : list[indexPath.row]
            cell?.textLabel?.text = playitem.path
            cell?.backgroundColor = (playitem.identify == viewModel.playingItem.value?.identify) ? .playingCell : .background
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
