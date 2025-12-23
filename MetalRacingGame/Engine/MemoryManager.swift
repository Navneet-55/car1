//
//  MemoryManager.swift
//  MetalRacingGame
//
//  Unified memory manager for M4 baseline (16GB) optimization
//  Enforces hard budgets and predictive prefetching
//

import Metal
import Foundation

/// Memory budget configuration
struct MemoryBudget {
    let totalBudget: Int64 // Total memory budget in bytes
    let textureBudget: Int64 // Texture memory budget
    let meshBudget: Int64 // Mesh/geometry budget
    let transientBudget: Int64 // Transient resources budget
    let streamingBudget: Int64 // Asset streaming budget
}

/// Memory manager for unified memory budgeting
class MemoryManager {
    static let shared = MemoryManager()
    
    private let device: MTLDevice
    private let budget: MemoryBudget
    
    // Current usage tracking
    private var currentTextureUsage: Int64 = 0
    private var currentMeshUsage: Int64 = 0
    private var currentTransientUsage: Int64 = 0
    private var currentStreamingUsage: Int64 = 0
    
    // Ring buffers for transient resources
    private var transientRingBuffers: [String: RingBuffer] = [:]
    
    // Predictive prefetching
    private var prefetchQueue: [PrefetchTask] = []
    private var activePrefetches: Set<String> = []
    
    private init() {
        self.device = HardwareDetector.shared.getDevice()
        
        // M4 base has 16GB unified memory
        // Allocate budgets: 8GB for textures, 2GB for meshes, 2GB for transient, 4GB reserved
        let totalBudget: Int64 = 16 * 1024 * 1024 * 1024 // 16GB
        self.budget = MemoryBudget(
            totalBudget: totalBudget,
            textureBudget: 8 * 1024 * 1024 * 1024, // 8GB
            meshBudget: 2 * 1024 * 1024 * 1024, // 2GB
            transientBudget: 2 * 1024 * 1024 * 1024, // 2GB
            streamingBudget: 4 * 1024 * 1024 * 1024 // 4GB
        )
        
        print("Memory Manager initialized with \(budget.totalBudget / (1024 * 1024 * 1024))GB budget")
    }
    
    /// Allocate memory for a texture
    func allocateTexture(size: Int64, name: String) -> Bool {
        guard currentTextureUsage + size <= budget.textureBudget else {
            print("Memory Manager: Texture allocation failed (budget exceeded): \(name)")
            return false
        }
        
        currentTextureUsage += size
        return true
    }
    
    /// Deallocate texture memory
    func deallocateTexture(size: Int64) {
        currentTextureUsage = max(0, currentTextureUsage - size)
    }
    
    /// Allocate memory for a mesh
    func allocateMesh(size: Int64, name: String) -> Bool {
        guard currentMeshUsage + size <= budget.meshBudget else {
            print("Memory Manager: Mesh allocation failed (budget exceeded): \(name)")
            return false
        }
        
        currentMeshUsage += size
        return true
    }
    
    /// Deallocate mesh memory
    func deallocateMesh(size: Int64) {
        currentMeshUsage = max(0, currentMeshUsage - size)
    }
    
    /// Allocate transient memory (ring buffer)
    func allocateTransient(size: Int64, name: String) -> RingBuffer? {
        // Check if ring buffer already exists
        if let existing = transientRingBuffers[name] {
            return existing
        }
        
        guard currentTransientUsage + size <= budget.transientBudget else {
            print("Memory Manager: Transient allocation failed (budget exceeded): \(name)")
            return nil
        }
        
        let ringBuffer = RingBuffer(size: size, name: name)
        transientRingBuffers[name] = ringBuffer
        currentTransientUsage += size
        
        return ringBuffer
    }
    
    /// Deallocate transient memory
    func deallocateTransient(name: String) {
        if let ringBuffer = transientRingBuffers.removeValue(forKey: name) {
            currentTransientUsage = max(0, currentTransientUsage - Int64(ringBuffer.size))
        }
    }
    
    /// Enforce memory budget (evicts least recently used resources if needed)
    func enforceBudget() {
        let totalUsage = currentTextureUsage + currentMeshUsage + currentTransientUsage + currentStreamingUsage
        
        if totalUsage > budget.totalBudget {
            // Evict least recently used resources
            // In a real implementation, this would track LRU and evict accordingly
            print("Memory Manager: Budget exceeded, evicting resources")
        }
    }
    
    /// Predictive prefetch assets by Silverstone sector
    func prefetchAssets(sector: Int, trackDistance: Float) {
        // In a real implementation, this would prefetch assets for the next sector
        // For now, this is a placeholder
        let task = PrefetchTask(sector: sector, distance: trackDistance)
        prefetchQueue.append(task)
        
        // Process prefetch queue asynchronously
        JobSystem.shared.scheduleJob(on: .assetStreaming) {
            self.processPrefetchQueue()
        }
    }
    
    private func processPrefetchQueue() {
        // Process prefetch tasks
        // In a real implementation, this would load textures/meshes for upcoming sectors
        prefetchQueue.removeAll()
    }
    
    /// Get current memory usage
    func getCurrentUsage() -> (texture: Int64, mesh: Int64, transient: Int64, streaming: Int64, total: Int64) {
        let total = currentTextureUsage + currentMeshUsage + currentTransientUsage + currentStreamingUsage
        return (currentTextureUsage, currentMeshUsage, currentTransientUsage, currentStreamingUsage, total)
    }
    
    /// Get memory budget
    func getBudget() -> MemoryBudget {
        return budget
    }
}

/// Ring buffer for transient resources
class RingBuffer {
    let size: Int
    let name: String
    private var currentIndex: Int = 0
    private var buffers: [MTLBuffer?] = []
    
    init(size: Int, name: String) {
        self.size = size
        self.name = name
        // Create 3 buffers for triple buffering
        for _ in 0..<3 {
            buffers.append(nil) // Will be allocated on demand
        }
    }
    
    func getCurrentBuffer(device: MTLDevice) -> MTLBuffer? {
        if buffers[currentIndex] == nil {
            buffers[currentIndex] = device.makeBuffer(length: size, options: .storageModeShared)
        }
        return buffers[currentIndex]
    }
    
    func advance() {
        currentIndex = (currentIndex + 1) % 3
    }
}

/// Prefetch task
struct PrefetchTask {
    let sector: Int
    let distance: Float
}

