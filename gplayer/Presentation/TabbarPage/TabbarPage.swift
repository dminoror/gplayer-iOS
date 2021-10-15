//
//  TabbarPage.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/3.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class TabbarPage: UITabBarController {
    
    //private var viewModel: TabbarViewModel!
    
    static func create(viewModel: TabbarViewModel) -> TabbarPage {
        let page = TabbarPage()
        //page.viewModel = viewModel
        return page
    }
    
    override func loadView() {
        super.loadView()
        self.tabBar.tintColor = .text
        self.tabBar.backgroundColor = .background
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //viewModel.viewDidLoad()
        //bind(viewModel: viewModel)
    }
    
    private func bind(viewModel: TabbarViewModel) {
        /*
        viewModel.navigationTitle.observe(on: self) { [weak self] (title) in
            self?.navigationItem.title = title
        }
        viewModel.leftNavigationItem.observe(on: self) { [weak self] (item) in
            self?.navigationItem.leftBarButtonItem = item
        }
        viewModel.rightNavigationItem.observe(on: self) { [weak self] (item) in
            self?.navigationItem.rightBarButtonItem = item
        }*/
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //viewModel.viewWillAppear()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //viewModel.viewDidAppear()
    }
}

