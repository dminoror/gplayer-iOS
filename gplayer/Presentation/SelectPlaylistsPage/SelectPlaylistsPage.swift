//
//  SelectPlaylistsPage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class SelectPlaylistsPage: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var viewModel: SelectPlaylistsViewModel!
    
    private var playlistTable: UITableView!
    
    static func create(viewModel: SelectPlaylistsViewModel) -> SelectPlaylistsPage {
        let page = SelectPlaylistsPage()
        page.viewModel = viewModel
        return page
    }
    
    override func loadView() {
        super.loadView()
        self.modalPresentationStyle = .fullScreen
        self.view.backgroundColor = .background
        
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.register(SelectPlaylistsCell.self, forCellReuseIdentifier: SelectPlaylistsCell.cellName)
        self.view.addSubview(tableView)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[tableView]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["tableView" : tableView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[tableView]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["tableView" : tableView]))
        self.playlistTable = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
        bind(viewModel: viewModel)
    }
    
    private func bind(viewModel: SelectPlaylistsViewModel) {
        //viewModel..observe(on: self, observerBlock: { [weak self] ( ) in
        //})
        viewModel.config.didSet(observer: self) { [weak self] (config) in
            self?.playlistTable.reloadData()
        }
    }
    private func unbind() {
        viewModel.config.remove(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
        self.navigationController?.isModalInPresentation = true
        self.title = "選擇播放列表"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "checkmark", color: .text), style: .done, target: self, action: #selector(ok_Clicked))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "xmark", color: .text), style: .done, target: self, action: #selector(cancel_Clicked))
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unbind()
    }
    
    @objc func ok_Clicked() {
        viewModel.okClicked(selected: playlistTable?.indexPathsForSelectedRows)
    }
    @objc func cancel_Clicked() {
        viewModel.cancelClicked()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let number = viewModel.config.value?.playlists?.count {
            return number
        }
        return 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: SelectPlaylistsCell.cellName) as? SelectPlaylistsCell,
            let playlists = viewModel.config.value?.playlists {
            let playlist = playlists[indexPath.row]
            cell.titleLabel.text = playlist.name
            cell.setCheck(isCheck: tableView.indexPathsForSelectedRows?.contains(indexPath) == true)
            return cell
        }
        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? SelectPlaylistsCell {
            cell.setCheck(isCheck: true)
        }
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? SelectPlaylistsCell {
            cell.setCheck(isCheck: false)
        }
    }
}

class SelectPlaylistsCell: UITableViewCell {
    static let cellName = "SelectPlaylistsCell"
    
    var check: UIImageView!
    var titleLabel: UILabel!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let check = UIImageView()
        check.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(check)
        self.contentView.addConstraint(NSLayoutConstraint(item: check, attribute: .centerY, relatedBy: .equal, toItem: self.contentView, attribute: .centerY, multiplier: 1, constant: 0))
        self.contentView.addConstraint(NSLayoutConstraint(item: check, attribute: .leading, relatedBy: .equal, toItem: self.contentView, attribute: .leading, multiplier: 1, constant: 8))
        self.check = check
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .text
        label.numberOfLines = 2
        self.contentView.addSubview(label)
        self.contentView.addConstraint(NSLayoutConstraint(item: label, attribute: .top, relatedBy: .equal, toItem: self.contentView, attribute: .top, multiplier: 1, constant: 4))
        self.contentView.addConstraint(NSLayoutConstraint(item: label, attribute: .bottom, relatedBy: .equal, toItem: self.contentView, attribute: .bottom, multiplier: 1, constant: -4))
        self.contentView.addConstraint(NSLayoutConstraint(item: label, attribute: .trailing, relatedBy: .equal, toItem: self.contentView, attribute: .trailing, multiplier: 1, constant: -8))
        self.contentView.addConstraint(NSLayoutConstraint(item: check, attribute: .trailing, relatedBy: .equal, toItem: label, attribute: .leading, multiplier: 1, constant: -4))
        self.titleLabel = label
    }
    
    func setCheck(isCheck: Bool) {
        check.image = isCheck ? UIImage.systemWithColor(systemName: "smallcircle.fill.circle", color: .text) : UIImage.systemWithColor(systemName: "circle", color: .text)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
