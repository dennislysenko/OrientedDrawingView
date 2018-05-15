//
//  NavigationControllerViewController.swift
//  OrientedDrawingView
//
//  Created by Dennis Lysenko on 10/6/15.
//

import UIKit

class NavigationController: UINavigationController {
    override var shouldAutorotate: Bool {
        return self.viewControllers.last is ViewController // ImageViewController doesn't autorotate
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if self.viewControllers.last is ImageViewController {
            return [.portrait]
        } else {
            return [.all]
        }
    }
}
