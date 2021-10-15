//
//  TabbarNaviExtension.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/17.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

extension UIViewController {
    
    var tabbarNavigationItem: UINavigationItem? {
        get {
            return self.navigationController?.tabBarController?.navigationItem
        }
    }
    
    func setTabbarNavigationTitle(title: String?) {
        self.navigationController?.tabBarController?.navigationItem.title = title
    }
    
    func setTabbarNavigationBack() {
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .done, target: self, action: #selector(tabbarNavigationBack_Clicked))
        backButton.tintColor = UIColor(commonType: .text)
        self.navigationController?.tabBarController?.navigationItem.leftBarButtonItem = backButton
    }
    
    @objc func tabbarNavigationBack_Clicked() {
        self.navigationController?.popViewController(animated: true)
    }
    
    func cleanTabbarNavigationBack() {
        self.navigationController?.tabBarController?.navigationItem.leftBarButtonItem = nil
    }
}


/*
let view = UIView()
view.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
view.backgroundColor = .black
self.view.addSubview(view)

let point = CGPoint(x: 240, y: 315)
var points = [CGPoint]()
points.append(CGPoint(x: point.x + 20, y: point.y - 40))
points.append(CGPoint(x: point.x + 10, y: point.y - 50))
points.append(CGPoint(x: point.x + 35, y: point.y - 25))
points.append(CGPoint(x: point.x + 5, y: point.y + 5))
points.append(CGPoint(x: point.x - 50, y: point.y - 50))
points.append(CGPoint(x: point.x + 20, y: point.y - 120))
points.append(CGPoint(x: point.x + 110, y: point.y - 30))
points.append(CGPoint(x: point.x + 10, y: point.y + 70))
points.append(CGPoint(x: point.x - 110, y: point.y - 50))
points.append(CGPoint(x: point.x + 60, y: point.y - 220))
points.append(CGPoint(x: point.x + 10, y: point.y - 270))
points.append(CGPoint(x: point.x + 10, y: point.y + 140))
points.append(CGPoint(x: point.x - 10, y: point.y + 120))
points.append(CGPoint(x: point.x + 10, y: point.y + 100))

for index in 0...(points.count - 2) {
    let point1 = points[index], point2 = points[index + 1]
    let path = UIBezierPath()
    path.move(to: point1)
    path.addLine(to: point2)
    let layer = CAShapeLayer()
    layer.path = path.cgPath
    layer.strokeColor = UIColor.white.cgColor
    layer.lineWidth = 10
    layer.lineCap = .round
    view.layer.addSublayer(layer)
}


let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
let image = renderer.image { (context) in
    view.layer.render(in: context.cgContext)
}
let filename = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("image")

print(filename)
if let data = image.pngData() {
    try? data.write(to: filename)
}
*/
