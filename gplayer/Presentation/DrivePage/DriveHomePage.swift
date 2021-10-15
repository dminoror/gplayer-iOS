//
//  DriveHomePage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit
import GoogleSignIn

class DriveHomePage: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var viewModel: DriveHomeViewModel!
    
    var entriesTable: UITableView!
    
    static func create(viewModel: DriveHomeViewModel) -> DriveHomePage {
        let page = DriveHomePage()
        page.viewModel = viewModel
        return page
    }
    
    override func loadView() {
        super.loadView()
        
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.register(gpListCell.self, forCellReuseIdentifier: gpListCell.cellName)
        self.view.addSubview(table)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[table]|", options: .directionLeadingToTrailing, metrics: nil, views: ["table" : table]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[table]|", options: .directionLeadingToTrailing, metrics: nil, views: ["table" : table]))
        self.entriesTable = table
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
    }
    
    private func bind(viewModel: DriveHomeViewModel) {
        viewModel.entries.didSet(observer: self) { [weak self] (entries) in
            self?.entriesTable.reloadData()
        }
    }
    func unbind() {
        viewModel.entries.remove(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setTabbarNavigationTitle(title: NSLocalizedString("tabbar_item_drives", comment: "drives"))
        viewModel.viewWillAppear()
        bind(viewModel: viewModel)
        setupNavigationItem()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unbind()
    }
    
    func setupNavigationItem() {
        tabbarNavigationItem?.leftBarButtonItem = nil
        tabbarNavigationItem?.rightBarButtonItem = nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.entries.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: gpListCell.cellName) as? gpListCell {
            cell.moreButton.isHidden = true
            let entry = viewModel.entries.value[indexPath.row]
            switch entry {
            case .add:
                cell.titleLabel.text = "Add Google account"
                cell.iconImage.image = UIImage(systemName: "plus.circle")?.withTintColor(.text).withRenderingMode(.alwaysOriginal)
                break
            case .google(let user):
                cell.titleLabel.text = user.profile.email
                cell.iconImage.image = UIImage(named: "googleDrive")
                break
            }
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.didSelectItem(at: indexPath.row, currentViewController: self)
    }
}

