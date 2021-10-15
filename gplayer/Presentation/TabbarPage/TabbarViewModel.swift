//
//  TabbarViewModel.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/8.
//  Copyright © 2020 dminoror. All rights reserved.
//

import Foundation

struct TabbarViewModelClosures {
}
protocol TabbarViewModelInput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func didSelectItem(at index: Int)
}

protocol TabbarViewModelOutput {
}

class TabbarViewModel: TabbarViewModelInput, TabbarViewModelOutput {
    
    private let closures: TabbarViewModelClosures?
    /*
    var navigationTitle: Observable<String?> = Observable(nil)
    var leftNavigationItem: Observable<UIBarButtonItem?> = Observable(nil)
    var rightNavigationItem: Observable<UIBarButtonItem?> = Observable(nil)
    */
    init(closures: TabbarViewModelClosures? = nil) {
        self.closures = closures
    }
    
    func viewDidLoad() {
    }
    func viewWillAppear() {
        
    }
    func viewDidAppear() {
    }
    
    func didSelectItem(at index: Int) {
    }
}

