//
//  PlayerPage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class AClass: NSObject {
}
class BClass: AClass {
    override init() {
        
    }
}

class PlayerPage: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var viewModel: PlayerViewModel!
    
    var playButton: UIButton!
    var prevButton: UIButton!
    var nextButton: UIButton!
    var closeButton: UIButton!
    var loopButton: UIButton!
    var randomButton: UIButton!
    var playlistButton: UIButton!
    
    var coverImage: UIImageView!
    var playlistTable: UITableView!
    var rotateView: UIView!
    var titleLabel: UILabel!
    var artistLabel: UILabel!
    var progressSlider: DLProgressSlider!
    var currentTimeLabel: UILabel!
    var totalTimeLabel: UILabel!
    
    var animators: [UIViewPropertyAnimator]?
    var animated: Bool = false
    
    
    static func create(viewModel: PlayerViewModel) -> PlayerPage {
        let page = PlayerPage()
        page.viewModel = viewModel
        return page
    }
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }
    
    var deinitCalled: (() -> Void)?
    deinit {
        deinitCalled?()
    }
    
    override func loadView() {
        super.loadView()
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
    }
    
    private func bind(viewModel: PlayerViewModel) {
        viewModel.playState.didSet(observer: self) { [weak self] (playState) in
            let image = playState ? UIImage(systemName: "pause.fill") : UIImage(systemName: "play.fill")
            self?.playButton?.setImage(image, for: .normal)
        }
        viewModel.playEnable.didSet(observer: self) { [weak self] (playEnable) in
            self?.playButton?.isEnabled = playEnable
        }
        viewModel.loopMode.didSet(observer: self) { [weak self] (loopMode) in
            switch (loopMode) {
            case .loop:
            self?.loopButton.alpha = 1
                self?.loopButton.setImage(UIImage(systemName: "repeat"), for: .normal)
            case .single:
            self?.loopButton.alpha = 1
                self?.loopButton.setImage(UIImage(systemName: "repeat.1"), for: .normal)
            case .none:
                self?.loopButton.setImage(UIImage(systemName: "repeat"), for: .normal)
                self?.loopButton.alpha = 0.5
            }
        }
        viewModel.randomMode.didSet(observer: self) { [weak self] (randomMode) in
            switch (randomMode) {
            case .none:
                self?.randomButton.alpha = 0.5
            case .random:
                self?.randomButton.alpha = 1
            }
        }
        viewModel.metadata.didSet(observer: self) { [weak self] (metadata) in
            self?.titleLabel.text = metadata?.title
            self?.artistLabel.text = metadata?.artist
            self?.coverImage.setCover(image: metadata?.cover, pointSize: 40)
        }
        viewModel.currentTime.didSet(observer: self) { [weak self] (time) in
            self?.currentTimeLabel.text = time.durationFormat
            self?.progressSlider.value = Float(time)
        }
        viewModel.totalTime.didSet(observer: self) { [weak self] (time) in
            self?.totalTimeLabel.text = time.durationFormat
            self?.progressSlider.maximumValue = Float(time)
        }
        viewModel.playlistMode.didSet(observer: self) { [weak self] (playlistMode) in
            if let weakSelf = self {
                if (playlistMode) {
                    weakSelf.showPlaylist(animated: weakSelf.animated)
                    weakSelf.isModalInPresentation = true
                }
                else {
                    weakSelf.showCover(animated: weakSelf.animated)
                    weakSelf.isModalInPresentation = false
                }
            }
        }
        viewModel.playlistIndex.didSet(observer: self) { [weak self] (playlistIndex) in
            guard let weakSelf = self else { return }
            weakSelf.playlistTable.reloadData()
            if (playlistIndex < weakSelf.viewModel.playlist.value?.count ?? 0) {
                if (weakSelf.animated) {
                    weakSelf.playlistTable.scrollToRow(at: IndexPath(row: playlistIndex, section: 0), at: .middle, animated: true)
                }
            }
        }
    }
    func unbind() {
        viewModel.playState.remove(observer: self)
        viewModel.playEnable.remove(observer: self)
        viewModel.randomMode.remove(observer: self)
        viewModel.loopMode.remove(observer: self)
        viewModel.metadata.remove(observer: self)
        viewModel.currentTime.remove(observer: self)
        viewModel.totalTime.remove(observer: self)
        viewModel.playlistMode.remove(observer: self)
        viewModel.playlistIndex.remove(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
        bind(viewModel: viewModel)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
        self.animated = true
        if let playlist = viewModel.playlist.value,
            viewModel.playlistIndex.value < playlist.count {
            playlistTable.scrollToRow(at: IndexPath(row: viewModel.playlistIndex.value, section: 0), at: .middle, animated: false)
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.animated = false
        unbind()
    }
    
    @objc func closeButton_Clicked() {
        viewModel.closeClicked()
    }
    @objc func loopButton_Clicked() {
        viewModel.loopModeClicked()
    }
    @objc func randomButton_Clicked() {
        viewModel.randomModeClicked()
    }
    
    @objc func playlistButton_Clicked() {
        viewModel.playlistClicked()
    }
    
    func showPlaylist(animated: Bool) {
        self.animators?.forEach({ $0.stopAnimation(true) })
        if (!animated) {
            self.coverImage.isHidden = true
            self.playlistTable.isHidden = false
            self.playlistTable.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
            self.rotateView.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
            return
        }
        playlistTable.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi), 0, 1, 0)
        let animator1 = UIViewPropertyAnimator(duration: 0.25, curve: .easeIn) { [weak self] in
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 2000
            self?.rotateView.layer.transform = CATransform3DRotate(transform, CGFloat(Double.pi) / 2, 0, 1, 0)
        }
        animator1.addCompletion { [weak self] (position) in
            if (position == .end) {
                self?.coverImage.isHidden = true
                self?.playlistTable.isHidden = false
            }
        }
        let animator2 = UIViewPropertyAnimator(duration: 0.25, curve: .easeOut) { [weak self] in
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 2000
            self?.rotateView.layer.transform = CATransform3DRotate(transform, CGFloat(Double.pi), 0, 1, 0)
        }
        animator2.addCompletion { [weak self] (position) in
            if (position == .end) {
                self?.playlistTable.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
                self?.rotateView.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
            }
        }
        let animators = [animator1, animator2]
        UIViewPropertyAnimator.runAnimators(animators: animators)
        self.animators = animators
    }
    func showCover(animated: Bool) {
        self.animators?.forEach({ $0.stopAnimation(true) })
        if (!animated) {
            self.playlistTable.isHidden = true
            self.coverImage.isHidden = false
            self.rotateView.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
            return
        }
        coverImage.layer.transform = CATransform3DRotate(CATransform3DIdentity, CGFloat(Double.pi), 0, 1, 0)
        let animator1 = UIViewPropertyAnimator(duration: 0.25, curve: .easeIn) { [weak self] in
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 2000
            self?.rotateView.layer.transform = CATransform3DRotate(transform, CGFloat(Double.pi) / 2, 0, 1, 0)
        }
        animator1.addCompletion { [weak self] (position) in
            if (position == .end) {
                self?.playlistTable.isHidden = true
                self?.coverImage.isHidden = false
            }
        }
        let animator2 = UIViewPropertyAnimator(duration: 0.25, curve: .easeOut) { [weak self] in
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 2000
            self?.rotateView.layer.transform = CATransform3DRotate(transform, CGFloat(Double.pi), 0, 1, 0)
        }
        animator2.addCompletion { [weak self] (position) in
            if (position == .end) {
                self?.coverImage.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
                self?.rotateView.layer.transform = CATransform3DRotate(CATransform3DIdentity, 0, 0, 1, 0)
            }
        }
        let animators = [animator1, animator2]
        UIViewPropertyAnimator.runAnimators(animators: animators)
        self.animators = animators
    }
    
    @objc func playButton_Clicked() {
        viewModel.playPauseClicked()
    }
    @objc func prevButton_Clicked() {
        viewModel.prevClicked()
    }
    @objc func nextButton_Clicked() {
        viewModel.nextClicked()
    }
    @objc func progressSeek() {
        viewModel.progressSeek(time: TimeInterval(progressSlider.value))
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let playlist = viewModel.playlist.value {
            return playlist.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let playlist = viewModel.playlist.value {
            var cell = tableView.dequeueReusableCell(withIdentifier: "playitemCell")
            if (cell == nil) {
                cell = UITableViewCell(style: .default, reuseIdentifier: "playitemCell")
                cell?.selectionStyle = .none
            }
            let playitem = playlist[indexPath.row]
            cell?.textLabel?.text = playitem.name
            cell?.backgroundColor = (indexPath.row == viewModel.playlistIndex.value) ? .playingCell : .background
            return cell!
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.playitemSelected(index: indexPath.row)
    }
    
    func setupUI() {
        self.view.backgroundColor = UIColor(commonType: .background)
        
        let sizeType = UIScreen.getSizeType()
        var distance: CGFloat = 0
        var buttonHeight: CGFloat = UIScreen.screenRatio(value: 40)
        if (sizeType == .iPhone) {
            distance = (UIScreen.main.bounds.width - (buttonHeight * 4) - (20 * 2)) / 3
        }
        else if (sizeType == .iPhoneX) {
            distance = 44
        }
        else {
            
        }
        
        let minorButtons = [UIButton(), UIButton(), UIButton(), UIButton()]
        for button in minorButtons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tintColor = .text
            self.view.addSubview(button)
            self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1, constant: -(20 + UIScreen.safeArea.bottom)))
            self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: buttonHeight))
            self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: button, attribute: .height, multiplier: 1, constant: 0))
        }
        self.view.addConstraint(NSLayoutConstraint(item: minorButtons[0], attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 20))
        self.view.addConstraint(NSLayoutConstraint(item: minorButtons[1], attribute: .leading, relatedBy: .equal, toItem: minorButtons[0], attribute: .trailing, multiplier: 1, constant: distance))
        self.view.addConstraint(NSLayoutConstraint(item: minorButtons[3], attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -20))
        self.view.addConstraint(NSLayoutConstraint(item: minorButtons[2], attribute: .trailing, relatedBy: .equal, toItem: minorButtons[3], attribute: .leading, multiplier: 1, constant: -distance))
        closeButton = minorButtons[0]
        loopButton = minorButtons[1]
        randomButton = minorButtons[2]
        playlistButton = minorButtons[3]
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        playlistButton.setImage(UIImage(systemName: "music.note.list"), for: .normal)
        randomButton.setImage(UIImage(systemName: "shuffle"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeButton_Clicked), for: .touchUpInside)
        loopButton.addTarget(self, action: #selector(loopButton_Clicked), for: .touchUpInside)
        randomButton.addTarget(self, action: #selector(randomButton_Clicked), for: .touchUpInside)
        playlistButton.addTarget(self, action: #selector(playlistButton_Clicked), for: .touchUpInside)
        
        
        let majorButtons = [UIButton(), UIButton(), UIButton()]
        buttonHeight = UIScreen.screenRatio(value: 48)
        for button in majorButtons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tintColor = .text
            self.view.addSubview(button)
            self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: minorButtons[0], attribute: .top, multiplier: 1, constant: -8))
            self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: buttonHeight))
            self.view.addConstraint(NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: button, attribute: .height, multiplier: 1, constant: 0))
        }
        self.view.addConstraint(NSLayoutConstraint(item: majorButtons[1], attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: majorButtons[0], attribute: .trailing, relatedBy: .equal, toItem: majorButtons[1], attribute: .leading, multiplier: 1, constant: UIScreen.screenRatio(value: -32)))
        self.view.addConstraint(NSLayoutConstraint(item: majorButtons[2], attribute: .leading, relatedBy: .equal, toItem: majorButtons[1], attribute: .trailing, multiplier: 1, constant: UIScreen.screenRatio(value: 32)))
        majorButtons[0].setImage(UIImage(systemName: "backward.end.fill"), for: .normal)
        majorButtons[2].setImage(UIImage(systemName: "forward.end.fill"), for: .normal)
        playButton = majorButtons[1]
        prevButton = majorButtons[0]
        nextButton = majorButtons[2]
        playButton.addTarget(self, action: #selector(playButton_Clicked), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(prevButton_Clicked), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextButton_Clicked), for: .touchUpInside)
        
        let slider = DLProgressSlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = .text
        slider.maximumTrackTintColor = .notLoadedProgress
        slider.cachedColor = .maxTrack
        var thumb = UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        thumb = thumb?.withTintColor(.text, renderingMode: .alwaysOriginal)
        slider.setThumbImage(thumb, for: .normal)
        slider.setThumbImage(thumb, for: .highlighted)
        slider.addTarget(self, action: #selector(progressSeek), for: .valueChanged)
        self.view.addSubview(slider)
        self.view.addConstraint(NSLayoutConstraint(item: slider, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: slider, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: -UIScreen.screenRatio(value: 40)))
        self.view.addConstraint(NSLayoutConstraint(item: slider, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: UIScreen.screenRatio(value: 30)))
        self.view.addConstraint(NSLayoutConstraint(item: slider, attribute: .bottom, relatedBy: .equal, toItem: majorButtons[0], attribute: .top, multiplier: 1, constant: -UIScreen.screenRatio(value: 16)))
        progressSlider = slider
        
        var labels = [UILabel(), UILabel()]
        for label in labels {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "00:00"
            label.textColor = .text
            label.font = UIFont.systemFont(ofSize: 14)
            self.view.addSubview(label)
            self.view.addConstraint(NSLayoutConstraint(item: label, attribute: .top, relatedBy: .equal, toItem: slider, attribute: .bottom, multiplier: 1, constant: 0))
        }
        self.view.addConstraint(NSLayoutConstraint(item: labels[0], attribute: .leading, relatedBy: .equal, toItem: slider, attribute: .leading, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: labels[1], attribute: .trailing, relatedBy: .equal, toItem: slider, attribute: .trailing, multiplier: 1, constant: 0))
        currentTimeLabel = labels[0]
        totalTimeLabel = labels[1]
        
        labels = [UILabel(), UILabel()]
        for label in labels {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "Title\n123"
            label.textColor = .text
            label.textAlignment = .center
            label.numberOfLines = 2
            label.font = UIFont.systemFont(ofSize: UIScreen.screenRatio(value: 16))
            self.view.addSubview(label)
            self.view.addConstraint(NSLayoutConstraint(item: label, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: UIScreen.screenRatio(value: 40)))
            self.view.addConstraint(NSLayoutConstraint(item: label, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint(item: label, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: -UIScreen.screenRatio(value: 40)))
        }
        self.view.addConstraint(NSLayoutConstraint(item: labels[0], attribute: .bottom, relatedBy: .equal, toItem: slider, attribute: .top, multiplier: 1, constant: -UIScreen.screenRatio(value: 8)))
        self.view.addConstraint(NSLayoutConstraint(item: labels[1], attribute: .bottom, relatedBy: .equal, toItem: labels[0], attribute: .top, multiplier: 1, constant: -UIScreen.screenRatio(value: 4)))
        titleLabel = labels[1]
        artistLabel = labels[0]
        
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(view)
        self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: labels[1], attribute: .top, multiplier: 1, constant: -UIScreen.screenRatio(value: 8)))
        self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: 0))
        self.rotateView = view
        
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFit
        view.addSubview(image)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[image]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["image" : image]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[image]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["image" : image]))
        coverImage = image
        //coverImage.isHidden = true
        
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .background
        view.addSubview(table)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[table]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["table" : table]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[table]-0-|", options: .directionLeadingToTrailing, metrics: nil, views: ["table" : table]))
        playlistTable = table
        playlistTable.isHidden = true
    }
}
