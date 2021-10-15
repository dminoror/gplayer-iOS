//
//  UIKitExtension.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

struct ViewModelAlertContent {
    let title: String?
    let message: String?
    var options: [ViewModelAlertOption]
}
struct ViewModelAlertOption {
    let title: String
    let type: UIAlertAction.Style
    let closure: (() -> Void)?
}
extension UIViewController {
    func showLoading() {
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(loadingView)
        self.view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
        self.view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0))
        loadingView.startAnimating()
    }
    
    func stopLoading() {
        if let loadingView = self.view.subviews.first(where: { (view) -> Bool in
            return view.isKind(of: UIActivityIndicatorView.self)
        }) {
            loadingView.removeFromSuperview()
        }
    }
    
    func showAlert(content: ViewModelAlertContent?) {
        let alert = UIAlertController(title: content?.title, message: content?.message, preferredStyle: .alert)
        if let options = content?.options {
            for (_, element) in options.enumerated() {
                alert.addAction(UIAlertAction(title: element.title, style: .default, handler: { (action) in
                    if let closure = element.closure {
                        closure()
                    }
                }))
            }
        }
        self.present(alert, animated: true, completion: nil)
    }
}

extension UIColor {
    
    enum CommonColors {
        case background
        case text
        case maxTrack
        case playingCell
        case notLoadedProgress
        case actionSheetBackground
        case actionSheetBorderLine
    }
    
    convenience init(commonType: CommonColors) {
        switch commonType {
        case .background:
            self.init(named: "Background")!
        case .text:
            self.init(named: "Text")!
        case .maxTrack:
            self.init(named: "MaxTrack")!
        case .playingCell:
            self.init(named: "PlayingCell")!
        case .notLoadedProgress:
            self.init(named: "NotLoadedProgress")!
        case .actionSheetBackground:
            self.init(named: "ActionSheetBackground")!
        case .actionSheetBorderLine:
            self.init(named: "ActionSheetBorderLine")!
        }
        
    }
    
    class var background: UIColor { get { return UIColor(commonType: .background) } }
    class var text: UIColor { get { return UIColor(commonType: .text) } }
    class var maxTrack: UIColor { get { return UIColor(commonType: .maxTrack) } }
    class var playingCell: UIColor { get { return UIColor(commonType: .playingCell) } }
    class var notLoadedProgress: UIColor { get { return UIColor(commonType: .notLoadedProgress) } }
    class var actionSheetBackground: UIColor { get { return UIColor(commonType: .actionSheetBackground) } }
    class var actionSheetBorderLine: UIColor { get { return UIColor(commonType: .actionSheetBorderLine) } }
}

extension UIScreen {
    enum sizeType {
        case iPhone
        case iPhoneX
        case iPad
    }
    static func getSizeType() -> sizeType {
        if (UIDevice().userInterfaceIdiom == .phone) {
            switch (UIScreen.main.nativeBounds.height) {
            case 1136, 1334, 1920, 2208:
                return .iPhone
            case 2436, 2688, 1792:
                return .iPhoneX
            default:
                return .iPhone
            }
        }
        else {
            return .iPad
        }
    }
    static func screenRatio(value: CGFloat) -> CGFloat {
        let type = UIScreen.getSizeType()
        if (type == .iPhoneX) {
            return value * 1.2
        }
        return value
    }
    static var safeArea: UIEdgeInsets {
        get {
            if let safeArea = UIApplication.shared.windows.first?.safeAreaInsets {
                return safeArea
            }
            return UIEdgeInsets.zero
        }
    }
    static var safeSize: CGSize {
        get {
            let safeArea = UIScreen.safeArea
            let size = CGSize(width: UIScreen.main.bounds.width - safeArea.left - safeArea.right, height: UIScreen.main.bounds.height - safeArea.top - safeArea.bottom)
            return size
        }
    }
    static func takeScreenshot(_ shouldSave: Bool = true) -> UIImage? {
        var screenshotImage: UIImage?
        guard let layer = UIApplication.shared.windows.first?.layer else { return nil }
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
        guard let context = UIGraphicsGetCurrentContext() else {return nil}
        layer.render(in:context)
        screenshotImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let image = screenshotImage, shouldSave {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        
        return screenshotImage
    }
}

extension UIImage {
    func resizeImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let newImage = renderer.image { [weak self] (context) in
            self?.draw(in: renderer.format.bounds)
        }
        return newImage
    }
    func resizeImage(width: CGFloat) -> UIImage {
        let size = CGSize(width: width, height:
            self.size.height * width / self.size.width)
        let renderer = UIGraphicsImageRenderer(size: size)
        let newImage = renderer.image { [weak self] (context) in
            self?.draw(in: renderer.format.bounds)
        }
        return newImage
    }
    func blur(radius: CGFloat) -> UIImage? {
        guard let gaussianBlurFilter = CIFilter(name: "CIGaussianBlur") else { return self }
        gaussianBlurFilter.setDefaults()
        guard let cgImage = self.cgImage else { return self }
        let inputImage = CIImage(cgImage: cgImage)
        gaussianBlurFilter.setValue(inputImage, forKey: kCIInputImageKey)
        gaussianBlurFilter.setValue((radius), forKey: kCIInputRadiusKey)
        guard let outputImage = gaussianBlurFilter.outputImage else { return self }
        let context = CIContext(options: nil)
        guard let outputCGImage = context.createCGImage(outputImage, from: inputImage.extent) else { return self }
        return UIImage(cgImage: outputCGImage)
    }
    
    class func systemWithColor(systemName: String, color: UIColor) -> UIImage? {
        if let image = UIImage(systemName: systemName) {
            return image.withTintColor(color).withRenderingMode(.alwaysOriginal)
        }
        return nil
    }
}

extension CALayer{
    func addBorder(edge: UIRectEdge, color: UIColor, thickness: CGFloat) {
        let borders = CALayer()
        switch edge {
        case .top:
            borders.frame = CGRect(x: 0, y: 0, width: frame.width, height: thickness);
            break
        case .bottom:
            borders.frame = CGRect(x: 0, y: frame.height - thickness, width: frame.width, height: thickness);
        case .left:
            borders.frame = CGRect(x: 0, y: 0 + thickness, width: thickness, height: frame.height - thickness * 2);
        case .right:
            borders.frame = CGRect(x: frame.width - thickness, y: 0 + thickness, width: thickness, height: frame.height - thickness * 2);
        default:
            break
        }
        borders.backgroundColor = color.cgColor;
        self.addSublayer(borders);
    }
}
