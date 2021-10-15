//
//  GoogleDrivePage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit
import SDWebImage

class GoogleDrivePage: UIViewController, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    private var viewModel: GoogleDriveViewModel!
    
    var fileTable: UITableView!
    var loadingView: UIActivityIndicatorView!
    
    static func create(viewModel: GoogleDriveViewModel) -> GoogleDrivePage {
        let page = GoogleDrivePage()
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
        table.estimatedRowHeight = 44
        table.clipsToBounds = true
        self.view.addSubview(table)
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[table]|", options: .directionLeadingToTrailing, metrics: nil, views: ["table" : table]))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[table]|", options: .directionLeadingToTrailing, metrics: nil, views: ["table" : table]))
        self.fileTable = table
        
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(loadingView)
        self.view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0))
        self.loadingView = loadingView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
    }
    
    private func bind(viewModel: GoogleDriveViewModel) {
        viewModel.files.didSet(observer: self) { [weak self] (files) in
            self?.fileTable.reloadData()
        }
        viewModel.showAlert.willSet(observer: self) { [weak self] (newValue, oldValue) in
            if let alert = newValue {
                self?.showAlert(content: alert)
            }
        }
        viewModel.loading.didSet(observer: self) { [weak self] (loading) in
            if (loading) {
                self?.loadingView.startAnimating()
                self?.loadingView.isHidden = false
            }
            else {
                self?.loadingView.stopAnimating()
                self?.loadingView.isHidden = true
            }
        }
        viewModel.moreSheet.willSet(observer: self) { (newValue, oldValue) in
            if let sheet = newValue {
                sheet.show(animated: true)
            }
        }
        viewModel.title.didSet(observer: self) { [weak self] (title) in
            self?.setTabbarNavigationTitle(title: title)
        }
    }
    private func unbind() {
        viewModel.files.remove(observer: self)
        viewModel.showAlert.remove(observer: self)
        viewModel.loading.remove(observer: self)
        viewModel.moreSheet.remove(observer: self)
        viewModel.title.remove(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
        bind(viewModel: viewModel)
        setupNavigationItem()
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
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
        self.setTabbarNavigationBack()
        let rightItem = UIBarButtonItem(image: UIImage.systemWithColor(systemName: "arrow.up.doc.fill", color: .text), style: .done, target: self, action: #selector(uploadConfig_Clicked))
        tabbarNavigationItem?.rightBarButtonItem = rightItem
    }
    
    @objc func uploadConfig_Clicked() {
        let alert = UIAlertController(title: "上傳播放清單", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "播放清單名稱"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "上傳", style: .default, handler: { [weak self, weak alert] (action) in
            if let name = alert?.textFields?[0].text {
                self?.viewModel.didClickUpload(name: name)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func moreButton_Clicked(sender: UIButton) {
        viewModel.didSelectItemMore(index: sender.tag)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.files.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.row < viewModel.files.value.count) {
            if let cell = tableView.dequeueReusableCell(withIdentifier: gpListCell.cellName) as? gpListCell {
                let file = viewModel.files.value[indexPath.row]
                cell.titleLabel.text = file.name
                cell.iconImage.image = file.iconImage
                if (file.isAudio) {
                    cell.setMoreHidden(isHidden: false)
                    cell.moreButton.tag = indexPath.row
                    if (cell.moreButton.allTargets.count == 0) {
                        cell.moreButton.addTarget(self, action: #selector(moreButton_Clicked(sender:)), for: .touchUpInside)
                    }
                }
                else {
                    cell.setMoreHidden(isHidden: true)
                }
                return cell
            }
        }
        else {
            var cell = tableView.dequeueReusableCell(withIdentifier: "loadingCell")
            if (cell == nil) {
                cell = UITableViewCell(style: .default, reuseIdentifier: "loadingCell")
                let loading = UIActivityIndicatorView(style: .large)
                loading.tag = 100
                cell?.contentView.addSubview(loading)
                cell?.contentView.addConstraint(NSLayoutConstraint(item: loading, attribute: .centerX, relatedBy: .equal, toItem: cell?.contentView, attribute: .centerX, multiplier: 1, constant: 0))
                cell?.contentView.addConstraint(NSLayoutConstraint(item: loading, attribute: .centerY, relatedBy: .equal, toItem: cell?.contentView, attribute: .centerY, multiplier: 1, constant: 0))
            }
            if let loading = cell?.contentView.viewWithTag(100) as? UIActivityIndicatorView {
                loading.startAnimating()
            }
            return cell!
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.didSelectItem(at: indexPath.row)
    }
}

class gpListCell: UITableViewCell {
    static let cellName = "gpListCell"
    
    var iconImage: UIImageView!
    var titleLabel: UILabel!
    var moreButton: UIButton!
    private var moreWidth: NSLayoutConstraint!
    private var moreTrailing: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFit
        self.contentView.addSubview(image)
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 32))
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: image, attribute: .height, multiplier: 1, constant: 0))
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .leading, relatedBy: .equal, toItem: self.contentView, attribute: .leading, multiplier: 1, constant: 4))
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: self.contentView, attribute: .centerY, multiplier: 1, constant: 0))
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: self.contentView, attribute: .top, multiplier: 1, constant: 4))
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .bottom, relatedBy: .lessThanOrEqual, toItem: self.contentView, attribute: .bottom, multiplier: 1, constant: -4))
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.textColor = .text
        self.contentView.addSubview(label)
        self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-4-[label]-4-|", options: .directionLeadingToTrailing, metrics: nil, views: ["label" : label]))
        self.contentView.addConstraint(NSLayoutConstraint(item: label, attribute: .leading, relatedBy: .equal, toItem: image, attribute: .trailing, multiplier: 1, constant: 8))
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .text
        self.contentView.addSubview(button)
        var layout = NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 28)
        self.contentView.addConstraint(layout)
        moreWidth = layout
        self.contentView.addConstraint(NSLayoutConstraint(item: button, attribute: .centerY, relatedBy: .equal, toItem: self.contentView, attribute: .centerY, multiplier: 1, constant: 0))
        layout = NSLayoutConstraint(item: button, attribute: .trailing, relatedBy: .equal, toItem: self.contentView, attribute: .trailing, multiplier: 1, constant: -4)
        self.contentView.addConstraint(layout)
        moreTrailing = layout
        self.contentView.addConstraint(NSLayoutConstraint(item: button, attribute: .leading, relatedBy: .equal, toItem: label, attribute: .trailing, multiplier: 1, constant: 4))
        
        iconImage = image
        titleLabel = label
        moreButton = button
    }
    
    func setMoreHidden(isHidden: Bool) {
        moreButton.isHidden = isHidden
        if (isHidden) {
            moreWidth.constant = 0
            moreTrailing.constant = 0
        }
        else {
            moreWidth.constant = 28
            moreTrailing.constant = -8
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
