//
//  UIViewPropertyAnimator.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/15.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

extension UIViewPropertyAnimator {
    static func runAnimators(animators: [UIViewPropertyAnimator]) {
        var animators = animators
        animators.reverse()
        continusAnimators(animators: animators)
    }
    static private func continusAnimators(animators: [UIViewPropertyAnimator]) {
        if let animator = animators.last {
            var animators = animators
            animators.removeLast()
            animator.addCompletion { (position) in
                if (position == .end) {
                    continusAnimators(animators: animators)
                }
            }
            animator.startAnimation()
        }
    }
}
