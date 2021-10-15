//
//  ParseUtility.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/9.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

extension TimeInterval {
    var durationFormat: String {
        get {
            let time = NSInteger(self)
            
            let seconds = time % 60
            let minutes = (time / 60) % 60
            let hours = (time / 3600)
            
            if (hours > 0) {
                return String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
            }
            else {
                return String(format: "%0.2d:%0.2d", minutes, seconds)
            }
        }
    }
}

extension String {
    static func available(string: String?) -> Bool {
        if let string = string,
            string.count > 0 {
            return true
        }
        return false
    }
}
