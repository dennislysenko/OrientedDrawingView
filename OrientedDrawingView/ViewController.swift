//
//  ViewController.swift
//  DrawingTest
//
//  Created by Dennis Lysenko on 10/6/15.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBOutlet weak var drawingView: DrawingView!
    @IBAction func clear(sender: AnyObject) {
        self.drawingView.clear()
    }
    @IBAction func undo(sender: AnyObject) {
        self.drawingView.undo()
    }
    @IBAction func redo(sender: AnyObject) {
        self.drawingView.redo()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination as? ImageViewController else {
            return assert(false)
        }
        
        destination.image = self.drawingView.generateCorrectlyOrientedImage()
    }

}

