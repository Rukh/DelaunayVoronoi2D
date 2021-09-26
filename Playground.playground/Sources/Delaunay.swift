
import simd

public protocol PointerHashable: AnyObject, Hashable {}

public extension PointerHashable {
    
    static func == (left: Self, right: Self) -> Bool {
        return left === right
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
}


// Work faster then Float on 64-bit systems
public typealias Point = SIMD2<Double>

public struct Delaunay {
    
    public struct Circle: Hashable {
        
        var center: Point
        var radius: Double
        
        public func contains(_ point: Point) -> Bool {
            simd_fast_distance(center, point) < radius
        }
        
    }
    
    public class TrianglePoint: PointerHashable {
        
        public let simd: Point
        
        public var x: Double { simd.x }
        public var y: Double { simd.y }
        
        public var parents: Set<Triangle> = []
        
        public init(x: Double, y: Double) {
            simd = .init(x, y)
        }
        
        func angle(_ point: Point) -> Double {
            atan2(point.y - y, point.x - x)
        }
        
        public func locus() -> [Point] {
            let points = parents
                .map { $0.circumcircle.center }
            return Array(points)
                .sorted { angle($0) < angle($1) }
        }
        
    }
    
    public class Triangle: PointerHashable {
                
        public struct Edge: Hashable {
            let start: TrianglePoint
            let end: TrianglePoint
        }
        
        public var a: TrianglePoint
        public var b: TrianglePoint
        public var c: TrianglePoint
        
        public var circumcircle: Circle
                
        public var edges: [Edge] { [
            Edge(start: a, end: b),
            Edge(start: b, end: c),
            Edge(start: c, end: a),
        ] }
        
        public init(a: TrianglePoint, b: TrianglePoint, c: TrianglePoint) {
            self.a = a
            self.b = b
            self.c = c
            self.circumcircle = Self.findCircumcircle(a: a.simd, b: b.simd, c: c.simd)
            [a, b, c].forEach { $0.parents.insert(self) }
        }
        
        func relise() {
            [a, b, c].forEach { $0.parents.remove(self) }
        }
        
        public func contains(_ point: TrianglePoint) -> Bool {
            point === a || point === b || point === c
        }
        
        public func contains(edge: Edge) -> Bool {
            contains(edge.start) && contains(edge.end)
        }

        public static func findCircumcircle(a: Point, b: Point, c: Point) -> Circle {
            // Mathematical algorithm from Wikipedia: Circumscribed circle
            let aLength = simd_length_squared(a)
            let bLength = simd_length_squared(b)
            let cLength = simd_length_squared(c)
            
            let s = simd_double2(
                simd_determinant(
                    simd_double3x3(
                        .init(aLength, a.y, 1),
                        .init(bLength, b.y, 1),
                        .init(cLength, c.y, 1)
                    )
                ),
                simd_determinant(
                    simd_double3x3(
                        .init(a.x, aLength, 1),
                        .init(b.x, bLength, 1),
                        .init(c.x, cLength, 1)
                    )
                )
            ) / 2

            let av = simd_determinant(
                simd_double3x3(
                    .init(a.x, a.y, 1),
                    .init(b.x, b.y, 1),
                    .init(c.x, c.y, 1)
                )
            )

            let bv = simd_determinant(
                simd_double3x3(
                    .init(a.x, a.y, aLength),
                    .init(b.x, b.y, bLength),
                    .init(c.x, c.y, cLength)
                )
            )

            let center = s / av
            let radius = sqrt(bv / av + length_squared(s) / pow(av, 2))
            return Circle(center: center, radius: radius)
        }
        
    }
    
    public let points: Set<TrianglePoint>
    public var triangulation: Set<Triangle>?
    
    public init<List: Sequence>(_ pointList: List) where List.Element == Point {
        let points = pointList.map { TrianglePoint(x: $0.x, y: $0.y) }
        self.points = Set(points)
    }
    
    /**
     Trinagulation by Bowyer-Watson algorithm. Its time complexity is O(n^2)
     - Parameter pointList: is a set of coordinates defining the points to be triangulated
     */
    @discardableResult
    public mutating func triangulate() -> Set<Triangle> {
        var result = Set<Triangle>()
        defer { self.triangulation = result }
        
        // superTriangle must be large enough to completely contain all the points in pointList
        let distance: Double = points
            .map { length_squared($0.simd) }
            .max() ?? 0
        let superPoligon = [
            TrianglePoint(x:  distance, y:  distance),
            TrianglePoint(x: -distance, y: -distance),
            TrianglePoint(x:  distance, y: -distance),
            TrianglePoint(x: -distance, y:  distance),
        ]
        [
            Triangle(a: superPoligon[0], b: superPoligon[1], c: superPoligon[2]),
            Triangle(a: superPoligon[0], b: superPoligon[1], c: superPoligon[3]),
        ]
        .forEach { result.insert($0) }
        
        // add all the points one at a time to the triangulation
        for point in points {
            var badTriangles = Set<Triangle>()
            // first find all the triangles that are no longer valid due to the insertion
            for triangle in result where triangle.circumcircle.contains(point.simd) {
                badTriangles.insert(triangle)
            }
            var polygon = Set<Triangle.Edge>()
            // find the boundary of the polygonal hole
            for triangle in badTriangles {
                for edge in triangle.edges {
                    var isUnique = true
                    for otherTriangle in badTriangles where otherTriangle != triangle {
                        if otherTriangle.contains(edge: edge) {
                            isUnique = false
                            break
                        }
                    }
                    if isUnique { polygon.insert(edge) }
                }
            }
            for triangle in badTriangles {
                triangle.relise()
                result.remove(triangle)
            }
            // re-triangulate the polygonal hole
            for edge in polygon {
                let newTriangle = Triangle(a: point, b: edge.start, c: edge.end)
                result.insert(newTriangle)
            }
        }
        // done inserting points, now clean up
        
        superPoligon
            .flatMap { $0.parents }
            .forEach {
                // $0.relise()
                result.remove($0) // remove triangles, but not relise locus points
            }
        
//        [superTriangle.a, superTriangle.b, superTriangle.c]
//            .flatMap { $0.parents }
//            .forEach {
////                $0.relise()
//                result.remove($0)
//            }
        return result
    }
    
}
