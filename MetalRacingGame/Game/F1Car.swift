//
//  F1Car.swift
//  MetalRacingGame
//
//  High-detail Formula 1 car model (Mercedes-era design language)
//

import Metal
import simd

/// F1-grade car with full exterior fidelity
class F1Car {
    private let device: MTLDevice
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var normalBuffer: MTLBuffer?
    private var texCoordBuffer: MTLBuffer?
    private var indexCount: Int = 0
    
    // Car dimensions (F1 regulations)
    let length: Float = 5.5 // meters
    let width: Float = 2.0 // meters (max width)
    let height: Float = 0.95 // meters (excluding halo)
    let wheelbase: Float = 3.6 // meters
    
    // Material properties
    var bodyColor: SIMD3<Float> = SIMD3<Float>(0.0, 0.4, 0.8) // Mercedes silver-blue
    var metallic: Float = 0.9
    var roughness: Float = 0.1 // High gloss for F1 paint
    
    // Component flags
    var hasHalo: Bool = true
    var hasWings: Bool = true
    var hasSidepods: Bool = true
    
    // Static cache for shared geometry
    private static var sharedVertexBuffer: MTLBuffer?
    private static var sharedIndexBuffer: MTLBuffer?
    private static var sharedNormalBuffer: MTLBuffer?
    private static var sharedTexCoordBuffer: MTLBuffer?
    private static var sharedIndexCount: Int = 0
    
    init(device: MTLDevice) {
        self.device = device
        
        // Check cache first to avoid rebuilding geometry for every car
        if let vb = F1Car.sharedVertexBuffer,
           let ib = F1Car.sharedIndexBuffer,
           let nb = F1Car.sharedNormalBuffer {
            self.vertexBuffer = vb
            self.indexBuffer = ib
            self.normalBuffer = nb
            self.texCoordBuffer = F1Car.sharedTexCoordBuffer
            self.indexCount = F1Car.sharedIndexCount
            return
        }
        
        buildGeometry()
        
        // Cache the buffers for future instances
        F1Car.sharedVertexBuffer = self.vertexBuffer
        F1Car.sharedIndexBuffer = self.indexBuffer
        F1Car.sharedNormalBuffer = self.normalBuffer
        F1Car.sharedTexCoordBuffer = self.texCoordBuffer
        F1Car.sharedIndexCount = self.indexCount
    }
    
    /// Build complete F1 car geometry
    private func buildGeometry() {
        var vertices: [Float] = []
        var normals: [Float] = []
        var texCoords: [Float] = []
        var indices: [UInt16] = []
        
        // Build main body (monocoque)
        buildMonocoque(&vertices, &normals, &texCoords, &indices)
        
        // Front wing
        if hasWings {
            buildFrontWing(&vertices, &normals, &texCoords, &indices)
        }
        
        // Rear wing
        if hasWings {
            buildRearWing(&vertices, &normals, &texCoords, &indices)
        }
        
        // Sidepods
        if hasSidepods {
            buildSidepods(&vertices, &normals, &texCoords, &indices)
        }
        
        // Halo
        if hasHalo {
            buildHalo(&vertices, &normals, &texCoords, &indices)
        }
        
        // Diffuser
        buildDiffuser(&vertices, &normals, &texCoords, &indices)
        
        // Wheels and suspension
        buildWheels(&vertices, &normals, &texCoords, &indices)
        buildSuspension(&vertices, &normals, &texCoords, &indices)
        
        // Create Metal buffers
        let vertexDataSize = vertices.count * MemoryLayout<Float>.stride
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexDataSize, options: [])
        
        let normalDataSize = normals.count * MemoryLayout<Float>.stride
        normalBuffer = device.makeBuffer(bytes: normals, length: normalDataSize, options: [])
        
        let texCoordDataSize = texCoords.count * MemoryLayout<Float>.stride
        if !texCoords.isEmpty {
            texCoordBuffer = device.makeBuffer(bytes: texCoords, length: texCoordDataSize, options: [])
        }
        
        let indexDataSize = indices.count * MemoryLayout<UInt16>.stride
        indexBuffer = device.makeBuffer(bytes: indices, length: indexDataSize, options: [])
        indexCount = indices.count
        
        print("F1 Car geometry built: \(vertices.count / 5) vertices, \(indices.count) indices")
    }
    
    /// Build main monocoque (cockpit area)
    private func buildMonocoque(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        var baseIndex = UInt16(vertices.count / 5)
        
        // Monocoque is a tapered box shape
        let frontWidth: Float = 1.4
        let rearWidth: Float = 0.8
        let frontHeight: Float = 0.6
        let rearHeight: Float = 0.7
        
        // Front face
        addQuad(
            p0: SIMD3<Float>(-frontWidth/2, 0, length/2),
            p1: SIMD3<Float>(frontWidth/2, 0, length/2),
            p2: SIMD3<Float>(frontWidth/2, frontHeight, length/2),
            p3: SIMD3<Float>(-frontWidth/2, frontHeight, length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Rear face
        addQuad(
            p0: SIMD3<Float>(-rearWidth/2, 0, -length/2),
            p1: SIMD3<Float>(rearWidth/2, 0, -length/2),
            p2: SIMD3<Float>(rearWidth/2, rearHeight, -length/2),
            p3: SIMD3<Float>(-rearWidth/2, rearHeight, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Top surface
        addQuad(
            p0: SIMD3<Float>(-frontWidth/2, frontHeight, length/2),
            p1: SIMD3<Float>(frontWidth/2, frontHeight, length/2),
            p2: SIMD3<Float>(rearWidth/2, rearHeight, -length/2),
            p3: SIMD3<Float>(-rearWidth/2, rearHeight, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Left side
        addQuad(
            p0: SIMD3<Float>(-frontWidth/2, 0, length/2),
            p1: SIMD3<Float>(-frontWidth/2, frontHeight, length/2),
            p2: SIMD3<Float>(-rearWidth/2, rearHeight, -length/2),
            p3: SIMD3<Float>(-rearWidth/2, 0, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Right side
        addQuad(
            p0: SIMD3<Float>(frontWidth/2, 0, length/2),
            p1: SIMD3<Float>(frontWidth/2, frontHeight, length/2),
            p2: SIMD3<Float>(rearWidth/2, rearHeight, -length/2),
            p3: SIMD3<Float>(rearWidth/2, 0, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build front wing assembly
    private func buildFrontWing(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        var baseIndex = UInt16(vertices.count / 5)
        
        // Main plane
        let wingWidth: Float = 2.0
        let wingDepth: Float = 0.3
        let wingHeight: Float = 0.15
        
        addQuad(
            p0: SIMD3<Float>(-wingWidth/2, wingHeight, length/2 + wingDepth),
            p1: SIMD3<Float>(wingWidth/2, wingHeight, length/2 + wingDepth),
            p2: SIMD3<Float>(wingWidth/2, wingHeight, length/2),
            p3: SIMD3<Float>(-wingWidth/2, wingHeight, length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Endplates
        addQuad(
            p0: SIMD3<Float>(-wingWidth/2, 0, length/2 + wingDepth),
            p1: SIMD3<Float>(-wingWidth/2, wingHeight, length/2 + wingDepth),
            p2: SIMD3<Float>(-wingWidth/2, wingHeight, length/2),
            p3: SIMD3<Float>(-wingWidth/2, 0, length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        addQuad(
            p0: SIMD3<Float>(wingWidth/2, 0, length/2 + wingDepth),
            p1: SIMD3<Float>(wingWidth/2, wingHeight, length/2 + wingDepth),
            p2: SIMD3<Float>(wingWidth/2, wingHeight, length/2),
            p3: SIMD3<Float>(wingWidth/2, 0, length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build rear wing assembly
    private func buildRearWing(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        var baseIndex = UInt16(vertices.count / 5)
        
        // Main plane (higher than front)
        let wingWidth: Float = 1.0
        let wingDepth: Float = 0.2
        let wingHeight: Float = 0.8
        
        addQuad(
            p0: SIMD3<Float>(-wingWidth/2, wingHeight, -length/2 - wingDepth),
            p1: SIMD3<Float>(wingWidth/2, wingHeight, -length/2 - wingDepth),
            p2: SIMD3<Float>(wingWidth/2, wingHeight, -length/2),
            p3: SIMD3<Float>(-wingWidth/2, wingHeight, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Endplates
        addQuad(
            p0: SIMD3<Float>(-wingWidth/2, 0.3, -length/2 - wingDepth),
            p1: SIMD3<Float>(-wingWidth/2, wingHeight, -length/2 - wingDepth),
            p2: SIMD3<Float>(-wingWidth/2, wingHeight, -length/2),
            p3: SIMD3<Float>(-wingWidth/2, 0.3, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        addQuad(
            p0: SIMD3<Float>(wingWidth/2, 0.3, -length/2 - wingDepth),
            p1: SIMD3<Float>(wingWidth/2, wingHeight, -length/2 - wingDepth),
            p2: SIMD3<Float>(wingWidth/2, wingHeight, -length/2),
            p3: SIMD3<Float>(wingWidth/2, 0.3, -length/2),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build sidepods (air intakes)
    private func buildSidepods(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        var baseIndex = UInt16(vertices.count / 5)
        
        // Left sidepod
        let sidepodWidth: Float = 0.4
        let sidepodHeight: Float = 0.5
        let sidepodLength: Float = 1.5
        let sidepodZ: Float = 0.5
        
        // Simplified box for sidepod
        addBox(
            center: SIMD3<Float>(-width/2 - sidepodWidth/2, sidepodHeight/2, sidepodZ),
            size: SIMD3<Float>(sidepodWidth, sidepodHeight, sidepodLength),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Right sidepod
        addBox(
            center: SIMD3<Float>(width/2 + sidepodWidth/2, sidepodHeight/2, sidepodZ),
            size: SIMD3<Float>(sidepodWidth, sidepodHeight, sidepodLength),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build halo (safety structure)
    private func buildHalo(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        var baseIndex = UInt16(vertices.count / 5)
        
        // Halo is a curved bar above the cockpit
        let haloHeight: Float = 1.2
        let haloWidth: Float = 0.6
        let haloThickness: Float = 0.05
        
        // Front support
        addBox(
            center: SIMD3<Float>(0, haloHeight, length/2 - 0.5),
            size: SIMD3<Float>(haloThickness, haloHeight * 0.6, haloThickness),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Top bar (curved, simplified as box)
        addBox(
            center: SIMD3<Float>(0, haloHeight, 0),
            size: SIMD3<Float>(haloWidth, haloThickness, 0.8),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build diffuser (rear underbody)
    private func buildDiffuser(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        var baseIndex = UInt16(vertices.count / 5)
        
        // Diffuser extends rearward and upward
        let diffuserWidth: Float = 1.2
        let diffuserDepth: Float = 0.4
        let diffuserHeight: Float = 0.2
        
        addQuad(
            p0: SIMD3<Float>(-diffuserWidth/2, 0, -length/2),
            p1: SIMD3<Float>(diffuserWidth/2, 0, -length/2),
            p2: SIMD3<Float>(diffuserWidth/2, diffuserHeight, -length/2 - diffuserDepth),
            p3: SIMD3<Float>(-diffuserWidth/2, diffuserHeight, -length/2 - diffuserDepth),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build wheels and tires
    private func buildWheels(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        let wheelRadius: Float = 0.33 // 13" wheel
        let tireRadius: Float = 0.36 // Tire outer radius
        let wheelWidth: Float = 0.4
        
        // Front left
        addCylinder(
            center: SIMD3<Float>(-width/2 - 0.3, wheelRadius, length/2 - 0.5),
            radius: tireRadius,
            height: wheelWidth,
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Front right
        addCylinder(
            center: SIMD3<Float>(width/2 + 0.3, wheelRadius, length/2 - 0.5),
            radius: tireRadius,
            height: wheelWidth,
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Rear left
        addCylinder(
            center: SIMD3<Float>(-width/2 - 0.3, wheelRadius, -length/2 + 0.5),
            radius: tireRadius,
            height: wheelWidth,
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
        
        // Rear right
        addCylinder(
            center: SIMD3<Float>(width/2 + 0.3, wheelRadius, -length/2 + 0.5),
            radius: tireRadius,
            height: wheelWidth,
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    /// Build suspension components
    private func buildSuspension(_ vertices: inout [Float], _ normals: inout [Float], _ texCoords: inout [Float], _ indices: inout [UInt16]) {
        // Simplified suspension arms (visible components)
        var baseIndex = UInt16(vertices.count / 5)
        
        // Front suspension
        addBox(
            center: SIMD3<Float>(0, 0.3, length/2 - 0.3),
            size: SIMD3<Float>(width + 0.6, 0.05, 0.1),
            baseIndex: &baseIndex,
            vertices: &vertices,
            normals: &normals,
            texCoords: &texCoords,
            indices: &indices
        )
    }
    
    // Helper functions for geometry generation
    private func addQuad(p0: SIMD3<Float>, p1: SIMD3<Float>, p2: SIMD3<Float>, p3: SIMD3<Float>, baseIndex: inout UInt16, vertices: inout [Float], normals: inout [Float], texCoords: inout [Float], indices: inout [UInt16]) {
        let normal = normalize(cross(p1 - p0, p3 - p0))
        
        vertices.append(contentsOf: [p0.x, p0.y, p0.z, 0, 0])
        vertices.append(contentsOf: [p1.x, p1.y, p1.z, 1, 0])
        vertices.append(contentsOf: [p2.x, p2.y, p2.z, 1, 1])
        vertices.append(contentsOf: [p3.x, p3.y, p3.z, 0, 1])
        
        normals.append(contentsOf: [normal.x, normal.y, normal.z])
        normals.append(contentsOf: [normal.x, normal.y, normal.z])
        normals.append(contentsOf: [normal.x, normal.y, normal.z])
        normals.append(contentsOf: [normal.x, normal.y, normal.z])
        
        indices.append(baseIndex)
        indices.append(baseIndex + 1)
        indices.append(baseIndex + 2)
        indices.append(baseIndex)
        indices.append(baseIndex + 2)
        indices.append(baseIndex + 3)
        
        baseIndex += 4
    }
    
    private func addBox(center: SIMD3<Float>, size: SIMD3<Float>, baseIndex: inout UInt16, vertices: inout [Float], normals: inout [Float], texCoords: inout [Float], indices: inout [UInt16]) {
        let halfSize = size * 0.5
        let corners = [
            SIMD3<Float>(center.x - halfSize.x, center.y - halfSize.y, center.z - halfSize.z),
            SIMD3<Float>(center.x + halfSize.x, center.y - halfSize.y, center.z - halfSize.z),
            SIMD3<Float>(center.x + halfSize.x, center.y + halfSize.y, center.z - halfSize.z),
            SIMD3<Float>(center.x - halfSize.x, center.y + halfSize.y, center.z - halfSize.z),
            SIMD3<Float>(center.x - halfSize.x, center.y - halfSize.y, center.z + halfSize.z),
            SIMD3<Float>(center.x + halfSize.x, center.y - halfSize.y, center.z + halfSize.z),
            SIMD3<Float>(center.x + halfSize.x, center.y + halfSize.y, center.z + halfSize.z),
            SIMD3<Float>(center.x - halfSize.x, center.y + halfSize.y, center.z + halfSize.z)
        ]
        
        // Add 6 faces
        addQuad(p0: corners[0], p1: corners[1], p2: corners[2], p3: corners[3], baseIndex: &baseIndex, vertices: &vertices, normals: &normals, texCoords: &texCoords, indices: &indices) // Front
        addQuad(p0: corners[4], p1: corners[7], p2: corners[6], p3: corners[5], baseIndex: &baseIndex, vertices: &vertices, normals: &normals, texCoords: &texCoords, indices: &indices) // Back
        addQuad(p0: corners[0], p1: corners[4], p2: corners[5], p3: corners[1], baseIndex: &baseIndex, vertices: &vertices, normals: &normals, texCoords: &texCoords, indices: &indices) // Bottom
        addQuad(p0: corners[3], p1: corners[2], p2: corners[6], p3: corners[7], baseIndex: &baseIndex, vertices: &vertices, normals: &normals, texCoords: &texCoords, indices: &indices) // Top
        addQuad(p0: corners[0], p1: corners[3], p2: corners[7], p3: corners[4], baseIndex: &baseIndex, vertices: &vertices, normals: &normals, texCoords: &texCoords, indices: &indices) // Left
        addQuad(p0: corners[1], p1: corners[5], p2: corners[6], p3: corners[2], baseIndex: &baseIndex, vertices: &vertices, normals: &normals, texCoords: &texCoords, indices: &indices) // Right
    }
    
    private func addCylinder(center: SIMD3<Float>, radius: Float, height: Float, baseIndex: inout UInt16, vertices: inout [Float], normals: inout [Float], texCoords: inout [Float], indices: inout [UInt16]) {
        let segments = 16
        let halfHeight = height * 0.5
        
        // Top and bottom circles
        for i in 0..<segments {
            let angle1 = Float(i) * 2.0 * Float.pi / Float(segments)
            let angle2 = Float(i + 1) * 2.0 * Float.pi / Float(segments)
            
            let x1 = cos(angle1) * radius
            let z1 = sin(angle1) * radius
            let x2 = cos(angle2) * radius
            let z2 = sin(angle2) * radius
            
            // Top face
            vertices.append(contentsOf: [center.x, center.y + halfHeight, center.z, 0.5, 0.5])
            vertices.append(contentsOf: [center.x + x1, center.y + halfHeight, center.z + z1, 0.5 + x1/radius * 0.5, 0.5 + z1/radius * 0.5])
            vertices.append(contentsOf: [center.x + x2, center.y + halfHeight, center.z + z2, 0.5 + x2/radius * 0.5, 0.5 + z2/radius * 0.5])
            
            normals.append(contentsOf: [0, 1, 0])
            normals.append(contentsOf: [0, 1, 0])
            normals.append(contentsOf: [0, 1, 0])
            
            indices.append(baseIndex)
            indices.append(baseIndex + 1)
            indices.append(baseIndex + 2)
            baseIndex += 3
            
            // Side face
            addQuad(
                p0: SIMD3<Float>(center.x + x1, center.y - halfHeight, center.z + z1),
                p1: SIMD3<Float>(center.x + x2, center.y - halfHeight, center.z + z2),
                p2: SIMD3<Float>(center.x + x2, center.y + halfHeight, center.z + z2),
                p3: SIMD3<Float>(center.x + x1, center.y + halfHeight, center.z + z1),
                baseIndex: &baseIndex,
                vertices: &vertices,
                normals: &normals,
                texCoords: &texCoords,
                indices: &indices
            )
        }
    }
    
    /// Get vertex buffer
    func getVertexBuffer() -> MTLBuffer? {
        return vertexBuffer
    }
    
    /// Get index buffer
    func getIndexBuffer() -> MTLBuffer? {
        return indexBuffer
    }
    
    /// Get normal buffer
    func getNormalBuffer() -> MTLBuffer? {
        return normalBuffer
    }
    
    /// Get index count
    func getIndexCount() -> Int {
        return indexCount
    }
    
    /// Get material properties
    func getMaterialProperties() -> (color: SIMD3<Float>, metallic: Float, roughness: Float) {
        return (bodyColor, metallic, roughness)
    }
}

