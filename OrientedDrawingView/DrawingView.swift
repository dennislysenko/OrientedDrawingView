//
//  DrawingView.swift
//  DrawingTest
//
//  Created by Dennis Lysenko on 10/6/15.
//

import UIKit

extension CGPoint {
    /// Converts a point in the coordinate system x: [0, size.width] y: [0, size.height] to the coordinate system x: [0, 1] y: [0, 1].
    func normalizedToSize(size: CGSize) -> CGPoint {
        return CGPoint(x: self.x / size.width, y: self.y / size.height)
    }
}

extension UIInterfaceOrientation {
    /// Gets the necessary angle to rotate by in order to compensate for device orientation.
    var angleDegrees: CGFloat {
        switch self {
        case .landscapeLeft: return 90
        case .landscapeRight: return 270
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }
}

/**
 Represents a single drawing action in a specific configuration.

 This allows you to create an "action" for drawing a line at the top when you were rotated to landscape and the drawing view was 320x568, then rotate to upside down portrait, size down the drawing view to 10x10, draw a line 3/4 of the way down from the new top, rotate to portrait and 320x320, and both lines will stretch perfectly to the same exact proportions they had relative to the drawing view in each of their source orientations & sizes.

 How? It stores a normalized path, meaning every point on it has an x and y value between 0 and 1. It also stores the orientation and DrawingView.bounds.size in which it was created (sourceOrientation and sourceBounds). As you add more subpaths to the path, it normalizes them based on sourceBounds. When it comes time to draw the path in a new configuration, it rotates the point about (0.5, 0.5) (ALWAYS the center after we've normalized the points :) by (newOrientation - sourceOrientation) degrees (see extension UIDeviceOrientation above) and then scales it to the new DrawingView bounds.
 */
public class Action: Codable {
    /// The orientation the device had when this action was started.
    var sourceOrientation: UIInterfaceOrientation

    /// The bounds the parent drawing view had when this action was started.
    var sourceBounds: CGSize

    /// The color of the stroke.
    var color: UIColor
    var strokeWidth: CGFloat

    private var sourcePath: CGMutablePath


    init(sourceOrientation: UIInterfaceOrientation, sourceBounds: CGSize, color: UIColor, strokeWidth: CGFloat) {
        self.sourceOrientation = sourceOrientation
        self.sourceBounds = sourceBounds
        self.color = color
        self.strokeWidth = strokeWidth
        self.sourcePath = CGMutablePath()
    }


    /// Rotates & scales the source path. See class swiftdoc.
    func getTransformedPath(orientation: UIInterfaceOrientation, bounds: CGSize) -> CGPath {
        let sourceAngle = self.sourceOrientation.angleDegrees
        let currentAngle = orientation.angleDegrees
        let diffDegrees = (currentAngle - sourceAngle + 360).truncatingRemainder(dividingBy: 360)
        let diff = diffDegrees * CGFloat.pi / 180

        let x: CGFloat = 0.5
        let y: CGFloat = 0.5

        let sx: CGFloat = bounds.width
        let sy: CGFloat = bounds.height
        var finalTransform = CGAffineTransform.init(a: cos(diff), b: sin(diff), c: -sin(diff), d: cos(diff), tx: x-x*cos(diff)+y*sin(diff), ty: y-x*sin(diff)-y*cos(diff))

        finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: sx, y: sy))

        return self.sourcePath.copy(using: &finalTransform)!
    }

    struct PathCurve: Codable {
        let start: CGPoint
        let end: CGPoint
        let control: CGPoint

        func createSubpath() -> CGMutablePath {
            let subpath = CGMutablePath()
            subpath.move(to: start)
            subpath.addQuadCurve(to: end, control: control)
            return subpath
        }
    }

    var pathCurves: [PathCurve] = []

    /// Adds a smooth subpath to the drawing path.
    func addPathAndGetBoundingBox(beforePreviousPoint _beforePreviousPoint: CGPoint, previousPoint _previousPoint: CGPoint, currentPoint _currentPoint: CGPoint) -> CGRect {
        let beforePreviousPoint = _beforePreviousPoint.normalizedToSize(size: self.sourceBounds)
        let previousPoint = _previousPoint.normalizedToSize(size: self.sourceBounds)
        let currentPoint = _currentPoint.normalizedToSize(size: self.sourceBounds)

        let mid1 = midpoint(p1: beforePreviousPoint, p2: previousPoint)
        let mid2 = midpoint(p1: previousPoint, p2: currentPoint)

        let pathCurve = PathCurve(start: mid1, end: mid2, control: previousPoint)
        self.pathCurves.append(pathCurve)
        let subpath = pathCurve.createSubpath()
        self.sourcePath.addPath(subpath)

        return subpath.boundingBox
    }

    private func midpoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case sourceOrientation
        case sourceBounds
        case strokeWidth

        // color
        case r
        case g
        case b
        case a

        // path curves
        case curves
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.sourceOrientation = UIInterfaceOrientation(rawValue: try container.decode(Int.self, forKey: .sourceOrientation)) ?? UIInterfaceOrientation.portrait
        self.sourceBounds = try container.decode(CGSize.self, forKey: .sourceBounds)
        self.strokeWidth = try container.decode(CGFloat.self, forKey: .strokeWidth)
        self.sourcePath = CGMutablePath()

        self.color = UIColor(
            red: try container.decode(CGFloat.self, forKey: .r),
            green: try container.decode(CGFloat.self, forKey: .g),
            blue: try container.decode(CGFloat.self, forKey: .b),
            alpha: try container.decode(CGFloat.self, forKey: .a)
        )

        self.pathCurves = try container.decode(Array<PathCurve>.self, forKey: .curves)
        self.pathCurves.map { $0.createSubpath() }.forEach { self.sourcePath.addPath($0) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.sourceOrientation.rawValue, forKey: .sourceOrientation)
        try container.encode(self.sourceBounds, forKey: .sourceBounds)
        try container.encode(self.strokeWidth, forKey: .strokeWidth)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        _ = self.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        try container.encode(red, forKey: .r)
        try container.encode(green, forKey: .g)
        try container.encode(blue, forKey: .b)
        try container.encode(alpha, forKey: .a)

        try container.encode(self.pathCurves, forKey: .curves)
    }
}

/**
 A view that accepts user drawing and displays it on screen.

 When rotated, this view will attempt to keep the same orientation on its drawing. Meaning, if you drew an arrow pointing to the HOME button and rotated your device to any other orientation, this DrawingView would rotate its internal display so that the arrow would still be pointing to the HOME button.
 */
@IBDesignable public class DrawingView: UIView {
    /// The color of lines that are drawn.
    @IBInspectable public var lineColor: UIColor = UIColor.blue

    /// The stroke width of lines that are drawn.
    @IBInspectable public var lineWidth: CGFloat = 8

    public var drawingEnabled = true

    public var allActions: [Action] = []
    private var redoStack: [Action] = []
    private var currentAction: Action?

    /// True if the user has not drawn anything or has cleared the drawing view.
    public var isEmpty: Bool {
        return allActions.isEmpty
    }

    /// Deletes all content from the drawing view.
    public func clear() {
        self.redoStack = []
        self.allActions = []
        self.setNeedsDisplay()
    }

    /// Undoes the last action in the drawing queue.
    public func undo() {
        guard !self.allActions.isEmpty else {
            return
        }

        self.redoStack.append(self.allActions.removeLast())
        self.setNeedsDisplay()
    }

    public func redo() {
        guard !self.redoStack.isEmpty else {
            return
        }

        self.allActions.append(self.redoStack.removeLast())
        self.setNeedsDisplay()
    }

    /**
     Generates the exact image that would be displayed on the screen if the device were in portrait orientation.
     */
    public func generateCorrectlyOrientedImage() -> UIImage {
        var portraitSize: CGSize
        if self.bounds.size.width < self.bounds.size.height {
            portraitSize = self.bounds.size
        } else {
            portraitSize = CGSize(width: self.bounds.size.height, height: self.bounds.size.width)
        }

        UIGraphicsBeginImageContextWithOptions(portraitSize, false, 0)
        self.drawActions(actions: self.allActions, bounds: portraitSize, currentOrientation: .portrait)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }


    // MARK: -
    public override func draw(_ rect: CGRect) {
        self.drawActions(actions: self.allActions, bounds: self.bounds.size)
    }

    public override func layoutSubviews() {
        // Detects rotation and forces redisplay.
        self.setNeedsDisplay()
    }

    // TODO: cache current actions into an image
    private func drawActions(actions: [Action], bounds: CGSize, currentOrientation: UIInterfaceOrientation = UIApplication.shared.statusBarOrientation) {
        let context = UIGraphicsGetCurrentContext()!
        for action in actions {
            let path = action.getTransformedPath(orientation: currentOrientation, bounds: bounds)
            context.addPath(path)
            context.setLineCap(.round)
            context.setLineWidth(action.strokeWidth)
            context.setStrokeColor(action.color.cgColor)
            context.setBlendMode(.normal)
            context.strokePath()
        }
    }

    private func finalizeCurrentAction() {
        guard let _ = self.currentAction else {
            assert(false)
            return
        }

        self.currentAction = nil
    }

    private var previousPoint, beforePreviousPoint, currentPoint: CGPoint?
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, self.drawingEnabled else {
            return
        }

        self.previousPoint = touch.previousLocation(in: self)
        self.currentPoint = touch.location(in: self)

        allActions.append(Action(sourceOrientation: UIApplication.shared.statusBarOrientation, sourceBounds: self.bounds.size, color: self.lineColor, strokeWidth: self.lineWidth))
        self.currentAction = allActions.last
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, self.drawingEnabled else {
            return
        }

        self.beforePreviousPoint = previousPoint
        self.previousPoint = touch.previousLocation(in: self)
        self.currentPoint = touch.location(in: self)

        guard let _ = self.currentAction?.addPathAndGetBoundingBox(beforePreviousPoint: self.beforePreviousPoint!, previousPoint: self.previousPoint!, currentPoint: self.currentPoint!) else {
            assert(false)
            return
        }

        var drawBox = bounds
        drawBox.origin.x -= self.lineWidth * 2
        drawBox.origin.y -= self.lineWidth * 2
        drawBox.size.width += self.lineWidth * 4
        drawBox.size.height += self.lineWidth * 4
        self.setNeedsDisplay(drawBox)

        self.redoStack = []
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchesMoved(touches, with: event)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        if let _ = touches {
            self.touchesMoved(touches!, with: event)
        }
    }
}
