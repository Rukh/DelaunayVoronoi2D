
import struct Foundation.Date
import PlaygroundSupport
import UIKit

// Trinagulation
let size = CGSize(width: 1280, height: 720)
let points = (0 ..< 1000).map { _ in
    Point(
        x: .random(in: 0 ... .init(size.width)),
        y: .random(in: 0 ... .init(size.height))
    )
}
var delaunay = Delaunay(points)
let time = Date().timeIntervalSince1970
delaunay.triangulate()
print("Triangles count:", delaunay.triangulation?.count ?? 0, "calculated by", Date().timeIntervalSince1970 - time, "seconds")

// Render
var pattern: [CGFloat] = [10, 8]
let image = UIGraphicsImageRenderer(size: size).image { ctx in
    UIColor.red.setFill()
    ctx.cgContext.fill(.infinite)
    for sitePoint in delaunay.points {
        let points = sitePoint.locus().map { CGPoint(x: $0.x, y: $0.y) }
        let path = UIBezierPath()
        points.last.flatMap { path.move(to: $0) }
        points.forEach { path.addLine(to: $0) }
                
        UIColor(white: .random(in: 0.4 ... 0.8), alpha: 1).setFill()
        UIColor.black.setStroke()
        
        path.lineWidth = 1
        
        path.fill()
        path.stroke()
    }
    for triangle in delaunay.triangulation! {
        let path = UIBezierPath()
        let points = [triangle.a, triangle.b, triangle.c].map { CGPoint(x: $0.x, y: $0.y) }
        points.last.flatMap { path.move(to: $0) }
        points.forEach { path.addLine(to: $0) }

        UIColor.black.setStroke()
        path.lineWidth = 0.5
        path.setLineDash(&pattern, count: 1, phase: 0)
        path.stroke()
    }
    for point in points {
        let point = CGPoint(x: point.x, y: point.y)
        let path = UIBezierPath(arcCenter: point, radius: 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        UIColor.black.setFill()
        path.fill()
    }
}

// Save file
let filepath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Example")
    .appendingPathExtension(for: .png)
try! image.pngData()?.write(to: filepath)
print("Write to:\n\(filepath.path)")
