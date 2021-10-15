/*
//
//  <MODELNAME>Page.swift
//  gplayer
//
//  Created by DoubleLight on 2020/9/7.
//  Copyright © 2020 dminoror. All rights reserved.
//

import UIKit

class <MODELNAME>Page: UIViewController {
    
    private var viewModel: <MODELNAME>ViewModel!
    
    static func create(viewModel: <MODELNAME>ViewModel) -> <MODELNAME>Page {
        let page = <MODELNAME>Page()
        page.viewModel = viewModel
        return page
    }
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
        bind(viewModel: viewModel)
    }
    
    private func bind(viewModel: <MODELNAME>ViewModel) {
        //viewModel..observe(on: self, observerBlock: { [weak self] ( ) in
        //})
    }
    private func unbind() {
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unbind()
    }
}
*/
