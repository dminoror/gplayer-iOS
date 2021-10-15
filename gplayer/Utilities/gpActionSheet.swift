//
//  gpActionSheet.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/21.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

struct gpActionSheetOption {
    var title: String?
    var icon: UIImage?
}

class gpActionSheet: UIView, UITableViewDelegate, UITableViewDataSource {
    
    let closures: [((UIViewAnimatingPosition) -> Void)?]
    let options: [gpActionSheetOption]
    let title: gpActionSheetOption
    
    static var rowHeight: CGFloat = 56
    static var footerHeight: CGFloat = 48
    
    private var table: UITableView!
    private var tableBottom: NSLayoutConstraint!
    private var backButton: UIButton!
    private var cellLeading: CGFloat = 0
    private var headerView: UIView!
    
    init(closures: [((UIViewAnimatingPosition) -> Void)?], title: gpActionSheetOption, options: [gpActionSheetOption]) {
        self.closures = closures
        self.title = title
        self.options = options
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        //print("deinit")
    }
    
    private var cellClosure: ((gpActionSheetCell) -> Void)?
    
    func calcLeading() {
        var maxWidth: CGFloat = 0
        let label = UILabel()
        for option in options {
            var iconWidth: CGFloat = 0, titleWidth: CGFloat = 0
            if let icon = option.icon {
                iconWidth = icon.size.width
            }
            if let title = option.title {
                label.text = title
                let size = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                titleWidth = size.width
            }
            if (maxWidth < iconWidth + titleWidth + 8) {
                maxWidth = iconWidth + titleWidth + 8
            }
        }
        if (maxWidth < self.frame.width) {
            let leading = (self.frame.width - maxWidth) / 2
            cellClosure = { (cell) in
                cell.leading.constant = leading
                cell.trailing.isActive = false
            }
        }
        else {
            cellClosure = { (cell) in
                cell.leading.constant = 4
                cell.leading.isActive = true
                cell.trailing.constant = 4
                cell.trailing.isActive = true
            }
        }
    }
    func calcHeader() {
        let imageWidth: CGFloat = 36, margin: CGFloat = 8
        let header = UIView()
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.image = self.title.icon
        header.addSubview(image)
        header.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: header, attribute: .centerY, multiplier: 1, constant: 0))
        header.addConstraint(NSLayoutConstraint(item: image, attribute: .leading, relatedBy: .equal, toItem: header, attribute: .leading, multiplier: 1, constant: margin))
        header.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: imageWidth))
        header.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: image, attribute: .width, multiplier: 1, constant: 0))
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = .text
        label.text = self.title.title
        header.addSubview(label)
        header.addConstraint(NSLayoutConstraint(item: label, attribute: .top, relatedBy: .equal, toItem: header, attribute: .top, multiplier: 1, constant: margin * 2))
        header.addConstraint(NSLayoutConstraint(item: label, attribute: .bottom, relatedBy: .equal, toItem: header, attribute: .bottom, multiplier: 1, constant: -margin * 2))
        header.addConstraint(NSLayoutConstraint(item: label, attribute: .leading, relatedBy: .equal, toItem: image, attribute: .trailing, multiplier: 1, constant: margin))
        header.addConstraint(NSLayoutConstraint(item: label, attribute: .trailing, relatedBy: .equal, toItem: header, attribute: .trailing, multiplier: 1, constant: -margin))
        let size = label.sizeThatFits(CGSize(width: self.frame.width - (margin * 3 + imageWidth), height: CGFloat.greatestFiniteMagnitude))
        if (size.height + (margin * 4) > imageWidth + margin * 4) {
            header.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: size.height + (margin * 4))
        }
        else {
            header.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: imageWidth + margin * 4)
        }
        header.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        header.layer.cornerRadius = 20
        header.backgroundColor = .actionSheetBackground
        self.headerView = header
    }
    
    func show(animated: Bool) {
        self.calcHeader()
        self.setupUI()
        self.calcLeading()
        UIApplication.shared.windows.first?.addSubview(self)
        let closure = { [weak self] in
            self?.backButton.alpha = 1
            self?.tableBottom.constant = -UIScreen.safeArea.bottom
            self?.layoutIfNeeded()
        }
        if (animated) {
            var image = UIScreen.takeScreenshot(false)
            image = image?.blur(radius: 10)
            backButton.setImage(image, for: .normal)
            backButton.isHidden = false
            
            table.isHidden = false
            let height = self.table.frame.height
            tableBottom.constant = -UIScreen.safeArea.bottom + height
            self.layoutIfNeeded()
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                closure()
            }, completion: nil)
        }
        else {
            closure()
        }
    }
    
    func hide(animated: Bool, closure: ((UIViewAnimatingPosition) -> Void)?) {
        let endClosure = { [weak self, closure] in
            self?.removeFromSuperview()
            if let closure = closure {
                closure(.end)
            }
        }
        if (animated) {
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
                guard let weakSelf = self else { return }
                weakSelf.backButton.alpha = 0
                weakSelf.tableBottom.constant = -UIScreen.safeArea.bottom + weakSelf.table.frame.height
                weakSelf.layoutIfNeeded()
            }) { (position) in
                endClosure()
            }
        }
        else {
            endClosure()
        }
    }
    
    @objc func backButton_Clicked() {
        hide(animated: true, closure: nil)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return gpActionSheet.rowHeight
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return headerView.frame.height
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return gpActionSheet.footerHeight
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let fotter = UIButton(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: gpActionSheet.footerHeight))
        fotter.setTitle("取消", for: .normal)
        fotter.addTarget(self, action: #selector(backButton_Clicked), for: .touchUpInside)
        fotter.setTitleColor(.text, for: .normal)
        fotter.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        fotter.layer.cornerRadius = 20
        fotter.backgroundColor = .actionSheetBackground
        fotter.layer.addBorder(edge: .top, color: .actionSheetBorderLine, thickness: 0.5)
        return fotter
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: gpActionSheetCell.reuseIdentifier) as? gpActionSheetCell {
            let option = options[indexPath.row]
            cell.titleLabel.text = option.title
            cell.iconImage.image = option.icon
            cellClosure!(cell)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var endClosure: ((UIViewAnimatingPosition) -> Void)?
        if (indexPath.row < closures.count),
            let closure = closures[indexPath.row] {
            closure(.start)
            endClosure = closure
        }
        hide(animated: true, closure: endClosure)
    }
    
    func setupUI() {
        self.backgroundColor = .clear
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(backButton_Clicked), for: .touchUpInside)
        self.addSubview(button)
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[button]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["button" : button]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[button]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["button" : button]))
        self.backButton = button
        button.alpha = 0
        
        let table = UITableView(frame: CGRect.zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.separatorStyle = .none
        table.register(gpActionSheetCell.self, forCellReuseIdentifier: gpActionSheetCell.reuseIdentifier)
        self.addSubview(table)
        let bottomConstraint = NSLayoutConstraint(item: table, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: -UIScreen.safeArea.bottom)
        bottomConstraint.identifier = "bottom"
        tableBottom = bottomConstraint
        self.addConstraint(bottomConstraint)
        self.addConstraint(NSLayoutConstraint(item: table, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: table, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0))
        let height = CGFloat(options.count) * gpActionSheet.rowHeight + self.headerView.frame.height + gpActionSheet.footerHeight
        if (height > UIScreen.safeSize.height) {
            self.addConstraint(NSLayoutConstraint(item: table, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: UIScreen.safeArea.top))
            table.isScrollEnabled = true
        }
        else {
            self.addConstraint(NSLayoutConstraint(item: table, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: height))
            table.isScrollEnabled = false
        }
        self.table = table
        table.isHidden = true
    }
}

class gpActionSheetCell: UITableViewCell {
    
    static let reuseIdentifier = "gpActionSheetCell"
    
    var iconImage: UIImageView!
    var titleLabel: UILabel!
    var leading: NSLayoutConstraint!
    var trailing: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(image)
        self.iconImage = image
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(label)
        self.titleLabel = label
        
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: self.contentView, attribute: .centerY, multiplier: 1, constant: 0))
        self.contentView.addConstraint(NSLayoutConstraint(item: label, attribute: .centerY, relatedBy: .equal, toItem: self.contentView, attribute: .centerY, multiplier: 1, constant: 0))
        self.contentView.addConstraint(NSLayoutConstraint(item: image, attribute: .trailing, relatedBy: .equal, toItem: label, attribute: .leading, multiplier: 1, constant: -8))
        
        let leading = NSLayoutConstraint(item: image, attribute: .leading, relatedBy: .equal, toItem: self.contentView, attribute: .leading, multiplier: 1, constant: 8)
        self.contentView.addConstraint(leading)
        self.leading = leading
        let trailing = NSLayoutConstraint(item: self.contentView, attribute: .trailing, relatedBy: .equal, toItem: label, attribute: .trailing, multiplier: 1, constant: 8)
        self.trailing = trailing
        self.contentView.backgroundColor = .actionSheetBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.contentView.layer.addBorder(edge: .top, color: .actionSheetBorderLine, thickness: 0.5)
    }
}
