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


        let circle = UIBezierPath(ovalIn: CGRect(x: 100, y: 100, width: 20, height: 20))
        let points = circle.cgPath.points()
        let newStroke = createCGPointToPKStroke(points: points)
        print(points)
        canvasView.drawing.strokes.append(newStroke)
        //let stroke = canvasView.drawing.strokes[0]
        //drawLine(point1: CGPoint(x: 0, y: 0), point2: CGPoint(x: 1000, y: 1000), color: .red, size: CGSize(width: 10, height: 10))

    }

    func drawLine(point1: CGPoint, point2: CGPoint, color: UIColor, size: CGSize) {
        //Define soints on strokePath
        let strokePoint1 = PKStrokePoint(location: point1, timeOffset: TimeInterval.init(), size: size, opacity: 2, force: 2, azimuth: 2, altitude: 1)
        let strokePoint2 = PKStrokePoint(location: point2, timeOffset: TimeInterval.init(), size: size, opacity: 2, force: 2, azimuth: 2, altitude: 1)
        //Define strokePath
        let strokePath = PKStrokePath(controlPoints: [strokePoint1, strokePoint2], creationDate: Date())
        //Define stroke
        let stroke = PKStroke(ink: PKInk(.pen, color: .red), path: strokePath)
        //Append stroke to strokes array in drawing
        canvasView.drawing.strokes.append(stroke)
    }

    var isUpdatingDrawing = false
}

extension DrawingViewController: PKCanvasViewDelegate {

    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        print("canvasViewDrawingDidChange")
        guard !isUpdatingDrawing else { return }

        let strokes: [PKStroke] = canvasView.drawing.strokes
        guard let path = strokes.last?.path else { return }

        guard let firstPoint = path.first, let lastPoint = path.last else { return }

        isUpdatingDrawing = true

        if firstPoint.approximatelyIntersects(lastPoint) {
            var pathLocations: [CGPoint] = []
            var slopes: [CGFloat] = []
            for point in path.interpolatedPoints(by: .distance(50)) {
                pathLocations.append(point.location)
            }
//            print(pathLocations)
//            for index in 1..<pathLocations.count {
//                let distanceX = pathLocations[index].x - pathLocations[index - 1].x
//                let distanceY = pathLocations[index].y - pathLocations[index - 1].y
//                let slope = CGFloat(distanceX/distanceY)
//                slopes.append(slope)
//            }
            //print(slopes)
            //let newStroke = createPloygon(points: pathLocations)
            canvasView.drawing.strokes.removeLast()
        } else {
            let newStroke = createLinearLine(firstPoint: firstPoint, lastPoint: lastPoint)
            canvasView.drawing.strokes[strokes.count - 1] = newStroke
        }

        isUpdatingDrawing = false
    }

    func createPloygon(points: [CGPoint]) -> [PKStroke] {
        let ink = PKInk(.pen, color: .red)
        var strokes: [PKStroke] = []


        let strokePoints = points.enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: 0.1 * TimeInterval(index), size: CGSize(width: 5, height: 5), opacity: 2, force: 1, azimuth: 0, altitude: 0)
        }

        var startStrokePoint = strokePoints.first!

        for strokePoint in strokePoints {
            let path = PKStrokePath(controlPoints: [startStrokePoint, strokePoint], creationDate: Date())
            strokes.append(PKStroke(ink: ink, path: path))
            startStrokePoint = strokePoint
        }

        return strokes
    }

    func createLinearLine(firstPoint: PKStrokePoint, lastPoint: PKStrokePoint) -> PKStroke {

        var newPoints: [PKStrokePoint] = []

        [firstPoint, lastPoint].forEach { point in
            let newPoint = PKStrokePoint(location: point.location,
                                         timeOffset: point.timeOffset,
                                         size: CGSize(width: 5,height: 5),
                                         opacity: CGFloat(1), force: point.force,
                                         azimuth: point.azimuth, altitude: point.altitude)
            newPoints.append(newPoint)
        }
        let newPath = PKStrokePath(controlPoints: newPoints, creationDate: Date())
        let circle = UIBezierPath(ovalIn: CGRect(x: 100, y: 100, width: 20, height: 20))
        let newStroke = PKStroke(ink: PKInk(.pen, color: .red), path: newPath, mask: circle)

        return newStroke
    }

    func createCGPointToPKStroke(points: [CGPoint]) -> PKStroke {
        let ink = PKInk(.pen, color: .red)

        let strokePoints = points.enumerated().map { index, point in
            PKStrokePoint(location: point,
                          timeOffset: TimeInterval.init(),
                          size: CGSize(width: 5, height: 5),
                          opacity: 2, force: 1,
                          azimuth: 0, altitude: 0)
        }

        let newPath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        let newStroke = PKStroke(ink: ink, path: newPath)
        return newStroke
    }

    func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
        print("canvasViewDidFinishRendering")
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidEndUsingTool")
        //        var pathLocations: [CGPoint] = []
        //        var slopes: [CGFloat] = []
        //        for path in lastStrokePath.interpolatedPoints(by: .distance(1)) {
        //            pathLocations.append(path.location)
        //        }
        //
        //        for index in 1..<pathLocations.count {
        //            let distanceX = pathLocations[index].x - pathLocations[index - 1].x
        //            let distanceY = pathLocations[index].y - pathLocations[index - 1].y
        //            let slope = CGFloat(distanceX/distanceY)
        //            slopes.append(slope)
        //        }
        //        print(slopes)
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidBeginUsingTool")
        //drawLine(point1: CGPoint(x: 0, y: 0), point2: CGPoint(x: 1000, y: 1000), color: .red, size: CGSize(width: 10, height: 10))
    }
}

extension DrawingViewController: CALayerDelegate {

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "position" {
            return NSNull()
        }
        return nil
    }
}


class CanvasView: PKCanvasView {

    enum ShapeCase {
        case circle
        case rectangle
        case triangle
        case ploygon
    }

    typealias SidePoints = (top: CGPoint, bottom: CGPoint, `left`: CGPoint, `right`: CGPoint)
    private var pointList: [CGPoint] = []
    private var isSnapToShape: Bool = false
    private var minimumStoppingPointCount = 50
    private var minimumDistanceBetweenPoints: CGFloat = 2

    private var stoppingPointCount: Int = 0

    let shape: ShapeCase = .rectangle

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
            print(stoppingPointCount)
            if stoppingPointCount > minimumStoppingPointCount { // If the gesture is recognized as a long press.

                guard let vertexs = getVertexsInPointList(points: pointList) else { return }

                switch shape {
                case .circle:
                    let circle = Circle(points: pointList)
                    let layer = circle.makeLayer()
                    self.layer.addSublayer(layer)

                case .rectangle:
                    let rectangle = Rectangle(points: pointList)
                    let layer = rectangle.makeLayer()
                    self.layer.addSublayer(layer)

                case .triangle:
                    let triangle = Triangle(points: pointList)
                    let layer = triangle.makeLayer()
                    self.layer.addSublayer(layer)

                case .ploygon:
                    let ploygon = Ploygon(points: pointList, vertexs: vertexs)
                    let layer = ploygon.makeLayer()
                    self.layer.addSublayer(layer)
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

    func sideLimitPoints(points: [CGPoint]) -> SidePoints? {
        let xSorted = points.sorted { $0.x < $1.x }
        let ySorted = points.sorted { $0.y < $1.y }
        guard let top = ySorted.first, let bottom = ySorted.last, let left = xSorted.first, let right = xSorted.last else { return nil }
        return (top, bottom, left, right)
    }

    func createPloyonLayer(sidePoints: SidePoints) -> CALayer {
        let (top, bottom, left, right) = sidePoints
        let path = UIBezierPath()
        path.move(to: CGPoint(x: top.x, y: top.y))
        path.addLine(to: CGPoint(x: left.x, y: left.y))
        path.addLine(to: CGPoint(x: bottom.x, y: bottom.y))
        path.addLine(to: CGPoint(x: right.x, y: right.y))
        path.addLine(to: CGPoint(x: top.x, y: top.y))

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 5

        return shapeLayer
    }


    func createPlogonLayer(vertexs: [CGPoint]) -> CALayer {

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

    func createCircleLayer(point: CGPoint) -> CALayer {
        let circleLayer = CALayer()
        circleLayer.frame = CGRect(x: point.x, y: point.y, width: 100, height: 100)
        circleLayer.borderColor = UIColor.red.cgColor
        circleLayer.borderWidth = 5
        circleLayer.cornerRadius = 50
        return circleLayer
    }

    func createRectangleLayer(point: CGPoint) -> CALayer {
        let circleLayer = CALayer()
        circleLayer.frame = CGRect(x: point.x, y: point.y, width: 100, height: 100)
        circleLayer.borderColor = UIColor.red.cgColor
        circleLayer.borderWidth = 5
        return circleLayer
    }

    func createTriangleLayer(point: CGPoint) -> CALayer {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: point.x, y: point.y + 100))
        path.addLine(to: CGPoint(x: point.x + 50, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 100, y: point.y + 100))
        path.addLine(to: CGPoint(x: point.x, y: point.y + 100))
        path.addClip()

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 5

        return shapeLayer
    }

    func getAngle(standardPoint: CGPoint, point1: CGPoint, point2: CGPoint) -> CGFloat {
        let vec1 = CGVector(dx: point1.x - standardPoint.x, dy: point1.y - standardPoint.y)
        let vec2 = CGVector(dx: point2.x - standardPoint.x, dy: point2.y - standardPoint.y)

        let theta1 = atan2f(Float(vec1.dy), Float(vec1.dx))
        let theta2 = atan2f(Float(vec2.dy), Float(vec2.dx))

        let angle = abs(Double(theta1 - theta2) / .pi * 180)
        return angle
    }

    func getVertexsInPointList(points: [CGPoint]) -> [CGPoint]? {
        let count = points.count
        if count < 3 { return nil }
        var vertexs: [CGPoint] = []
        for i in 3..<points.count {

            let standardPoint = points[i - 1]
            let angle = getAngle(standardPoint: standardPoint, point1: points[i-2], point2: points[i])


            print("angle", angle)
            if abs(180 - angle) > 30  {
                vertexs.append(standardPoint)
            }

        }
        let angle = getAngle(standardPoint: points[0], point1: points[1], point2: points[count - 2])
        if abs(180 - angle) > 30  {
            vertexs.append(points[0])
        }
        print(vertexs)
        return vertexs
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


class Circle: Shape {

    init(points: [CGPoint]) {
        super.init(points: points)
    }

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

class Ploygon: Shape {

    override init(points: [CGPoint], vertexs: [CGPoint]) {
        super.init(points: points, vertexs: vertexs)
    }

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

class Rectangle: Shape {

    init(points: [CGPoint]) {
        super.init(points: points)
    }

    override func makeLayer() -> CALayer {
        let circleLayer = CAShapeLayer()
        circleLayer.frame = layerFrame
        circleLayer.borderColor = UIColor.red.cgColor
        circleLayer.borderWidth = 5
        circleLayer.lineJoin = CAShapeLayerLineJoin.round
        return circleLayer
    }
}

// MARK: - Linear Equation x'x + y'y + a = 0
struct LinearEquation {
    let xCoefficient: CGFloat
    let yCoefficient: CGFloat
    let constant: CGFloat
}



extension PKStrokePoint {

    func approximatelyIntersects(_ point: PKStrokePoint) -> Bool {
        let origin = CGRect(origin: self.location, size: CGSize(width: 0.1, height: 0.1))
        let target = CGRect(origin: point.location, size: CGSize(width: 0.1, height: 0.1))
        return origin.intersects(target)
    }
}

extension CGPoint {

    func approximatelyIntersects(_ point: CGPoint) -> Bool {
        let origin = CGRect(origin: self, size: CGSize(width: 0.1, height: 0.1))
        let target = CGRect(origin: point, size: CGSize(width: 0.1, height: 0.1))
        //print(origin, target, origin.contains(target))
        return origin.contains(target)
    }

    func distance(point: CGPoint) -> CGFloat {
        let abstractX = self.x - point.x
        let abstractY = self.y - point.y

        let distance = abs(sqrt(pow(abstractX,2) + pow(abstractY,2)))
        return distance
    }
}

extension CGPath {
    func points() -> [CGPoint]
    {
        var bezierPoints = [CGPoint]()
        forEach(body: { (element: CGPathElement) in
            let numberOfPoints: Int = {
                switch element.type {
                case .moveToPoint, .addLineToPoint: // contains 1 point
                    return 1
                case .addQuadCurveToPoint: // contains 2 points
                    return 2
                case .addCurveToPoint: // contains 3 points
                    return 3
                case .closeSubpath:
                    return 0
                }
            }()
            for index in 0..<numberOfPoints {
                let point = element.points[index]
                bezierPoints.append(point)
            }
        })
        return bezierPoints
    }

    func forEach(body: @escaping @convention(block) (CGPathElement) -> Void) {
        typealias Body = @convention(block) (CGPathElement) -> Void

        func callback(info: UnsafeMutableRawPointer?, element: UnsafePointer<CGPathElement>) {
            let body = unsafeBitCast(info, to: Body.self)
            body(element.pointee)
        }

        let unsafeBody = unsafeBitCast(body, to: UnsafeMutableRawPointer.self)
        apply(info: unsafeBody, function: callback)
    }
}
