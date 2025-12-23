//
//  Track.swift
//  MetalRacingGame
//
//  Procedural track generation and rendering
//

import Foundation
import simd
import Metal

/// Track segment for procedural generation
struct TrackSegment {
    var position: SIMD3<Float>
    var direction: SIMD3<Float>
    var width: Float
    var curvature: Float // -1 to 1, negative = left, positive = right
}

class Track {
    private var segments: [TrackSegment] = []
    private var vertices: [Float] = []
    private var indices: [UInt16] = []
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    
    let length: Float
    let width: Float = 8.0 // Track width in meters
    
    init(device: MTLDevice, length: Float = 1000.0) {
        self.length = length
        generateProceduralTrack()
        createGeometry(device: device)
    }
    
    /// Generate procedural racing track
    private func generateProceduralTrack() {
        let segmentCount = 100
        let segmentLength: Float = length / Float(segmentCount)
        
        var currentPos = SIMD3<Float>(0, 0, 0)
        var currentDir = SIMD3<Float>(0, 0, -1)
        
        for i in 0..<segmentCount {
            // Vary curvature for interesting track
            let t = Float(i) / Float(segmentCount)
            let curvature = sin(t * 3.14159 * 4.0) * 0.3 // S-curve pattern
            
            // Update direction based on curvature
            let angle = curvature * segmentLength
            let rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            currentDir = rotation.act(currentDir)
            
            // Move forward
            currentPos += currentDir * segmentLength
            
            // Add elevation variation
            currentPos.y = sin(t * 3.14159 * 2.0) * 2.0
            
            let segment = TrackSegment(
                position: currentPos,
                direction: currentDir,
                width: width,
                curvature: curvature
            )
            segments.append(segment)
        }
    }
    
    /// Create track geometry for rendering
    private func createGeometry(device: MTLDevice) {
        // Generate vertices for track surface
        for (index, segment) in segments.enumerated() {
            let right = cross(segment.direction, SIMD3<Float>(0, 1, 0))
            let halfWidth = segment.width * 0.5
            
            let leftEdge = segment.position - right * halfWidth
            let rightEdge = segment.position + right * halfWidth
            
            // Add vertices (position + normal + uv)
            // Left vertex
            vertices.append(contentsOf: [leftEdge.x, leftEdge.y, leftEdge.z, 0, 1, 0, Float(index) / Float(segments.count), 0])
            // Right vertex
            vertices.append(contentsOf: [rightEdge.x, rightEdge.y, rightEdge.z, 0, 1, 0, Float(index) / Float(segments.count), 1])
        }
        
        // Generate indices for triangles
        for i in 0..<(segments.count - 1) {
            let base = UInt16(i * 2)
            // First triangle
            indices.append(base)
            indices.append(base + 1)
            indices.append(base + 2)
            // Second triangle
            indices.append(base + 1)
            indices.append(base + 3)
            indices.append(base + 2)
        }
        
        // Create Metal buffers
        if !vertices.isEmpty {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
        }
        if !indices.isEmpty {
            indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
        }
    }
    
    /// Get track position at distance
    func getPositionAt(distance: Float) -> SIMD3<Float> {
        let segmentIndex = Int((distance / length) * Float(segments.count))
        let clampedIndex = min(max(segmentIndex, 0), segments.count - 1)
        return segments[clampedIndex].position
    }
    
    /// Get track direction at distance
    func getDirectionAt(distance: Float) -> SIMD3<Float> {
        let segmentIndex = Int((distance / length) * Float(segments.count))
        let clampedIndex = min(max(segmentIndex, 0), segments.count - 1)
        return segments[clampedIndex].direction
    }
    
    /// Get vertex buffer for rendering
    func getVertexBuffer() -> MTLBuffer? {
        return vertexBuffer
    }
    
    /// Get index buffer for rendering
    func getIndexBuffer() -> MTLBuffer? {
        return indexBuffer
    }
    
    /// Get index count
    func getIndexCount() -> Int {
        return indices.count
    }
}

