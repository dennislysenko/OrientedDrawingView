//
//  ImageViewController.swift
//  OrientedDrawingView
//
//  Created by Dennis Lysenko on 10/6/15.
//

import UIKit

class ImageViewController: UIViewController {
    var image: UIImage!
    
    @IBOutlet weak var imageView: UIImageView!

    @IBAction func goBack(_ sender: AnyObject) {
        self.dismiss(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.imageView.image = self.image
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait]
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
}
