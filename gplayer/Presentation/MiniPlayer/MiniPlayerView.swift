//
//  MiniPlayerView.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/8.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class MiniPlayerView: UIView {
    
    private var viewModel: MiniPlayerViewModel!
    
    var coverImage: UIImageView!
    var titleLabel: UILabel!
    var playButton: UIButton!
    var progressBorder: CAShapeLayer!
    var loadingBorder: CAShapeLayer!
    
    static func create(viewModel: MiniPlayerViewModel) -> MiniPlayerView {
        let view = MiniPlayerView()
        view.viewModel = viewModel
        return view
    }
    convenience init() {
        self.init(frame: CGRect.zero)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(commonType: .background)
        let coverImage = UIImageView()
        coverImage.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(coverImage)
        self.addConstraint(NSLayoutConstraint(item: coverImage, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: coverImage, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: coverImage, attribute: .width, relatedBy: .equal, toItem: coverImage, attribute: .height, multiplier: 1, constant: 0))
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        titleLabel.textColor = UIColor(commonType: .text)
        self.addSubview(titleLabel)
        self.addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 4))
        self.addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: -4))
        let playButton = UIButton()
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playButton_Clicked(_:)), for: .touchUpInside)
        playButton.tintColor = UIColor(commonType: .text)
        self.addSubview(playButton)
        self.addConstraint(NSLayoutConstraint(item: playButton, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 8))
        self.addConstraint(NSLayoutConstraint(item: playButton, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: -8))
        self.addConstraint(NSLayoutConstraint(item: playButton, attribute: .width, relatedBy: .equal, toItem: playButton, attribute: .height, multiplier: 1, constant: 0))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[coverImage]-8-[titleLabel]-8-[playButton]-8-|", options: .directionLeadingToTrailing, metrics: nil, views: ["coverImage" : coverImage, "titleLabel" : titleLabel, "playButton" : playButton]))
        self.coverImage = coverImage
        self.titleLabel = titleLabel
        self.playButton = playButton
        let gesture = UITapGestureRecognizer(target: self, action: #selector(miniPlayer_Clicked))
        self.addGestureRecognizer(gesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if (progressBorder == nil) {
            let backBorder = CAShapeLayer()
            backBorder.lineWidth = 2
            backBorder.fillColor = UIColor.clear.cgColor
            backBorder.strokeColor = UIColor(commonType: .maxTrack).cgColor
            backBorder.frame = self.playButton!.bounds
            let aDegree = CGFloat.pi / 180
            let path = UIBezierPath()
            path.addArc(withCenter: CGPoint(x: playButton!.frame.width / 2, y: playButton!.frame.width / 2), radius: playButton!.frame.width / 2, startAngle: aDegree * -90, endAngle: aDegree * 450, clockwise: true)
            backBorder.path = path.cgPath
            playButton!.layer.addSublayer(backBorder)
            
            progressBorder = CAShapeLayer()
            progressBorder!.lineWidth = 3
            progressBorder!.fillColor = UIColor.clear.cgColor
            progressBorder!.strokeColor = UIColor(commonType: .text).cgColor
            progressBorder!.frame = playButton!.bounds
            playButton!.layer.addSublayer(progressBorder!)
            
            let layer = CAShapeLayer()
            layer.lineWidth = 3
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor(commonType: .text).cgColor
            layer.frame = playButton!.bounds
            playButton!.layer.addSublayer(layer)
            loadingBorder = layer
        }
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if (newWindow != nil) {
            self.viewModel.viewWillAppear()
            self.bind(viewModel: self.viewModel)
        }
        else {
            self.viewModel.viewWillDisappear()
            self.unbind(viewModel: self.viewModel)
        }
    }
    
    private func bind(viewModel: MiniPlayerViewModel) {
        viewModel.playState.didSet(observer: self) { [weak self] (playState) in
            let image = playState ? UIImage(systemName: "pause.fill") : UIImage(systemName: "play.fill")
            self?.playButton?.setImage(image, for: .normal)
        }
        viewModel.playEnable.didSet(observer: self) { [weak self] (playEnable) in
            self?.playButton?.isEnabled = playEnable
        }
        viewModel.progress.didSet(observer: self) { [weak self] (progress) in
            self?.updateProgress(progress: progress)
        }
        viewModel.metadata.didSet(observer: self) { [weak self] (metadata) in
            self?.titleLabel?.text = metadata?.title
            self?.coverImage.setCover(image: metadata?.cover, pointSize: 20)
        }
        viewModel.loading.didSet(observer: self) { [weak self] (loading) in
            print(loading)
            if (loading) {
                self?.startLoading()
            }
            else {
                self?.stopLoading()
            }
        }
    }
    private func unbind(viewModel: MiniPlayerViewModel) {
        viewModel.playState.remove(observer: self)
        viewModel.playEnable.remove(observer: self)
        viewModel.progress.remove(observer: self)
        viewModel.metadata.remove(observer: self)
    }
    
    func updateProgress(progress: Double) {
        if let playButtonBorder = progressBorder {
            let progressAngle = progress * 360
            let aDegree = CGFloat.pi / 180
            let path = UIBezierPath()
            path.addArc(withCenter: CGPoint(x: playButton!.frame.width / 2, y: playButton!.frame.width / 2), radius: playButton!.frame.width / 2, startAngle: aDegree * (-90), endAngle: aDegree * CGFloat((-90 + progressAngle)), clockwise: true)
            playButtonBorder.path = path.cgPath
        }
    }
    
    func startLoading() {
        progressBorder.path = nil
        if let keys = loadingBorder.animationKeys(),
            keys.count > 0{
            return
        }
        let path = UIBezierPath()
        let length = 60
        let degress = CGFloat.pi / 180
        path.addArc(withCenter: CGPoint(x: playButton!.frame.width / 2, y: playButton!.frame.width / 2), radius: playButton!.frame.width / 2, startAngle: degress * (-90), endAngle: degress * CGFloat((-90 + length)), clockwise: true)
        loadingBorder?.path = path.cgPath
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.fromValue = 0
        animation.toValue = Double.pi * 2
        animation.duration = 1
        animation.repeatDuration = CFTimeInterval.infinity
        loadingBorder?.add(animation, forKey: "transform.rotation")
    }
    func stopLoading() {
        loadingBorder?.path = nil
        loadingBorder?.removeAllAnimations()
    }
    
    @objc func playButton_Clicked(_ sender: Any) {
        PlayerCore.shared.switchState()
    }
    
    @objc func miniPlayer_Clicked() {
        viewModel.didClickMiniPlayer()
    }
}

extension UIImageView {
    func setCover(image: UIImage?, pointSize: CGFloat) {
        if (image != nil) {
            self.image = image
            self.contentMode = .scaleAspectFit
            self.backgroundColor = .clear
        }
        else {
            self.image = UIImage(systemName: "music.note", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular))?.withTintColor(.background, renderingMode: .alwaysOriginal)
            self.contentMode = .center
            self.backgroundColor = .playingCell
        }
    }
}

