/*
See LICENSE folder for this sample’s licensing information.

Abstract:
`DrawingViewController` is the primary view controller for showing drawings.
*/

///`PKCanvasView` is the main drawing view that you will add to your view hierarchy.
/// The drawingPolicy dictates whether drawing with a finger is allowed.  If it's set to default and if the tool picker is visible,
/// then it will respect the global finger pencil toggle in Settings or as set in the tool picker.  Otherwise, only drawing with
/// a pencil is allowed.

/// You can add your own class as a delegate of PKCanvasView to receive notifications after a user
/// has drawn or the drawing was updated. You can also set the tool or toggle the ruler on the canvas.

/// There is a shared tool picker for each window. The tool picker floats above everything, similar
/// to the keyboard. The tool picker is moveable in a regular size class window, and fixed to the bottom
/// in compact size class. To listen to tool picker notifications, add yourself as an observer.

/// Tool picker visibility is based on first responders. To make the tool picker appear, you need to
/// associate the tool picker with a `UIResponder` object, such as a view, by invoking the method
/// `UIToolpicker.setVisible(_:forResponder:)`, and then by making that responder become the first

/// Best practices:
///
/// -- Because the tool picker palette is floating and moveable for regular size classes, but fixed to the
/// bottom in compact size classes, make sure to listen to the tool picker's obscured frame and adjust your UI accordingly.

/// -- For regular size classes, the palette has undo and redo buttons, but not for compact size classes.
/// Make sure to provide your own undo and redo buttons when in a compact size class.

import UIKit
import PencilKit

class DrawingViewController: UIViewController, PKToolPickerObserver, UIScreenshotServiceDelegate {
    
    @IBOutlet weak var canvasView: CanvasView!
    @IBOutlet var undoBarButtonitem: UIBarButtonItem!
    @IBOutlet var redoBarButtonItem: UIBarButtonItem!
    
    var toolPicker: PKToolPicker!
    var signDrawingItem: UIBarButtonItem!
    
    /// On iOS 14.0, this is no longer necessary as the finger vs pencil toggle is a global setting in the toolpicker
    var pencilFingerBarButtonItem: UIBarButtonItem!

    /// Standard amount of overscroll allowed in the canvas.
    static let canvasOverscrollHeight: CGFloat = 500
    
    /// Data model for the drawing displayed by this view controller.
    var dataModelController: DataModelController!
    
    /// Private drawing state.
    var drawingIndex: Int = 0
    var hasModifiedDrawing = false
    
    // MARK: View Life Cycle
    
    /// Set up the drawing initially.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //setupUI()
        canvasView.delegate = self
        canvasView.drawingPolicy = .pencilOnly
        canvasView.tool = PKInkingTool(.pen, color: .red, width: 10)
        canvasView.becomeFirstResponder()
    }

    var isUpdatingDrawing = false
}

extension DrawingViewController: PKCanvasViewDelegate {

    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        print("canvasViewDrawingDidChange")
        let strokes: [PKStroke] = canvasView.drawing.strokes
        guard let path = strokes.last?.path else { return }
        canvasView.drawing.strokes.removeLast()
    }

    func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
        print("canvasViewDidFinishRendering")
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidEndUsingTool")
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidBeginUsingTool")
    }
}

class CanvasView: PKCanvasView {

    enum ShapeCase {
        case circle
        case rectangle
        case ploygon
    }

    typealias SidePoints = (top: CGPoint, bottom: CGPoint, `left`: CGPoint, `right`: CGPoint)
    private var pointList: [CGPoint] = []
    private var isSnapToShape: Bool = false
    private var minimumStoppingPointCount = 50
    private var minimumDistanceBetweenPoints: CGFloat = 4

    private var stoppingPointCount: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else {return }

        if isSnapToShape { return }
        if touch.type != .pencil { return }

        let count = pointList.count
        if count == 0 {
            pointList.append(touch.location(in: self))
            return
        }

        let lastPoint = pointList[count - 1]
        let currentPoint = touch.location(in: self)
        let distance = lastPoint.distance(point: currentPoint)

        if distance < minimumDistanceBetweenPoints { // If touches didn't move.
            stoppingPointCount += 1

            if stoppingPointCount > minimumStoppingPointCount { // If the gesture is recognized as a long press.

                guard let startPoint = pointList.first, let lastPoint = pointList.last else { return }

                if !startPoint.approximatelyIntersects(lastPoint) {

                    let linear = Linear(startPoint: startPoint, lastPoint: lastPoint)
                    let layer = linear.makeLayer()
                    self.layer.addSublayer(layer)

                } else {
                    guard let vertexs = getVertexsInPointList(points: pointList) else { return }
                    let shape = getShapeRecognized(vertexs: vertexs)

                    switch shape {
                    case .circle:
                        let circle = Circle(points: pointList)
                        let layer = circle.makeLayer()
                        self.layer.addSublayer(layer)

                    case .rectangle:
                        let rectangle = Rectangle(points: pointList)
                        let layer = rectangle.makeLayer()
                        self.layer.addSublayer(layer)

                    case .ploygon:
                        let ploygon = Ploygon(points: pointList, vertexs: vertexs)
                        let layer = ploygon.makeLayer()
                        self.layer.addSublayer(layer)
                    }
                }

                isSnapToShape = true
                stoppingPointCount = 0
                pointList.removeAll()
            }
            return
        }
        stoppingPointCount = 0
        pointList.append(currentPoint)
    }

    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        super.touchesEstimatedPropertiesUpdated(touches)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        pointList.removeAll()
        isSnapToShape = false
        stoppingPointCount = 0
    }

    func getShapeRecognized(vertexs: [CGPoint]) -> ShapeCase {
        if vertexs.count < 3 {
            return .circle

        } else if vertexs.count == 4 {

            for index in 0..<vertexs.count {
                let slopeValue = calculateSlopeBetweenPointToPoint(point1: vertexs[index],
                                                                   point2: vertexs[vertexs.nextIndex(at: index)])
                let slope = Slope(slopValue: slopeValue)

                if slope == .neitherVerticalNorHorizontal {
                    return .ploygon
                }
            }
            return .rectangle

        } else {
            return .ploygon
        }
    }

    enum Slope {
        case verticalOrHorizontal
        case almostVerticalOrHorizontal
        case neitherVerticalNorHorizontal

        init(slopValue: CGFloat) {
            if slopValue > 30 || slopValue < 0.1 {
                self = .verticalOrHorizontal
            } else if (10 < slopValue && slopValue < 30) || (0.1 <= slopValue && slopValue < 1.0 ) {
                self = .almostVerticalOrHorizontal
            } else {
                self = .neitherVerticalNorHorizontal
            }
        }
    }

    func calculateSlopeBetweenPointToPoint(point1: CGPoint, point2: CGPoint) -> CGFloat {
        let distanceX = abs(point1.x - point2.x)
        let distanceY = abs(point1.y - point2.y)
        return distanceX / distanceY
    }

    func sideLimitPoints(points: [CGPoint]) -> SidePoints? {
        let xSorted = points.sorted { $0.x < $1.x }
        let ySorted = points.sorted { $0.y < $1.y }
        guard let top = ySorted.first, let bottom = ySorted.last, let left = xSorted.first, let right = xSorted.last else { return nil }
        return (top, bottom, left, right)
    }

    func getAngle(centerPoint: CGPoint, point1: CGPoint, point2: CGPoint) -> CGFloat {
        let vec1 = CGVector(dx: point1.x - centerPoint.x, dy: point1.y - centerPoint.y)
        let vec2 = CGVector(dx: point2.x - centerPoint.x, dy: point2.y - centerPoint.y)

        let theta1 = atan2f(Float(vec1.dy), Float(vec1.dx))
        let theta2 = atan2f(Float(vec2.dy), Float(vec2.dx))

        let angle = abs(Double(theta1 - theta2) / .pi * 180)
        return angle
    }

    func getVertexsInPointList(points: [CGPoint]) -> [CGPoint]? {
        let count = points.count
        if count < 4 { return nil }
        var vertexs: [CGPoint] = []

        for i in 3..<points.count {

            let centerPoint = points[i - 1]
            let angle = getAngle(centerPoint: centerPoint, point1: points[i-2], point2: points[i])

            if abs(180 - angle) > 30 && ( vertexs.count == 0 || vertexs[vertexs.count - 1].distance(point: centerPoint) > 8) {
                vertexs.append(centerPoint)
            }
        }

        let angle = getAngle(centerPoint: points[0], point1: points[1], point2: points[count - 3])
        if abs(180 - angle) > 30  && ( vertexs.count == 0 || vertexs[vertexs.count - 1].distance(point: points[0]) > 8) {
            vertexs.append(points[0])
        }

        return vertexs
    }
}

extension Collection {

    func nextIndex(at index: Int) -> Int {
        if index >= (self.count - 1) {
            return 0
        }
        return (index + 1)
    }

    func previousIndex(at index: Int) -> Int {
        if index <= 0 {
            return self.count - 1
        }
        return index - 1
    }
}

class Linear {

    let startPoint: CGPoint
    let lastPoint: CGPoint

    init(startPoint: CGPoint, lastPoint:CGPoint) {
        self.startPoint = startPoint
        self.lastPoint = lastPoint
    }

    func makeLayer() -> CALayer {
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: lastPoint)
        path.close()

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 5
        shapeLayer.lineJoin = CAShapeLayerLineJoin.round

        return shapeLayer
    }
}


class Shape {

    let points: [CGPoint]
    var vertexs: [CGPoint]

    var startPoints: CGPoint {
        return points[0]
    }

    var layerFrame : CGRect {
        let count = points.count
        let xSorted = points.sorted { $0.x < $1.x }
        let ySorted = points.sorted { $0.y < $1.y }
        return CGRect(x: xSorted[0].x, y: ySorted[0].y, width: xSorted[count - 1].x - xSorted[0].x, height: ySorted[count - 1].y - ySorted[0].y)
    }

    init(points: [CGPoint], vertexs: [CGPoint] = []) {
        self.points = points
        self.vertexs = vertexs
    }

    func makeLayer() -> CALayer {
        let circleLayer = CALayer()
        circleLayer.frame = CGRect(x: self.startPoints.x, y: self.startPoints.y, width: 100, height: 100)
        circleLayer.borderColor = UIColor.red.cgColor
        circleLayer.borderWidth = 5
        circleLayer.cornerRadius = 50
        return circleLayer
    }
}

class Triangle: Shape {

    init(points: [CGPoint]) {
        super.init(points: points)
    }

    override func makeLayer() -> CALayer {
        let circleLayer = CALayer()
        circleLayer.frame = CGRect(x: self.startPoints.x, y: self.startPoints.y, width: 100, height: 100)
        circleLayer.borderColor = UIColor.red.cgColor
        circleLayer.borderWidth = 5
        circleLayer.cornerRadius = 50
        return circleLayer
    }
}

final class Circle: Shape {

    override func makeLayer() -> CALayer {
        let path = UIBezierPath(ovalIn: layerFrame)
        let circleLayer = CAShapeLayer()
        circleLayer.path = path.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.red.cgColor
        circleLayer.lineWidth = 5
        return circleLayer
    }
}

final class Rectangle: Shape {

    override func makeLayer() -> CALayer {
        let circleLayer = CAShapeLayer()
        circleLayer.frame = layerFrame
        circleLayer.borderColor = UIColor.red.cgColor
        circleLayer.borderWidth = 5
        circleLayer.cornerRadius = 2
        return circleLayer
    }
}


final class Ploygon: Shape {

    override func makeLayer() -> CALayer {
        let path = UIBezierPath()
        path.addClip()
        path.move(to: vertexs[0])
        for index in 1..<vertexs.count {
            path.addLine(to: vertexs[index])
        }
        path.addLine(to: vertexs[0])
        path.close()

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 5
        shapeLayer.lineJoin = CAShapeLayerLineJoin.round

        return shapeLayer
    }
}

extension CGPoint {

    func approximatelyIntersects(_ point: CGPoint) -> Bool {
        let offset = 50// 확대 되냐 안되냐에 따라 바뀌어야할 듯
        let origin = CGRect(origin: self, size: CGSize(width: offset, height: offset))
        let target = CGRect(origin: point, size: CGSize(width: offset, height: offset))
        return origin.intersects(target)
    }

    func distance(point: CGPoint) -> CGFloat {
        let abstractX = self.x - point.x
        let abstractY = self.y - point.y

        let distance = abs(sqrt(pow(abstractX,2) + pow(abstractY,2)))
        return distance
    }
}
