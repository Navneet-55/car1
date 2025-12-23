//
//  JobSystem.swift
//  MetalRacingGame
//
//  Job system with explicit thread pools for M4 baseline optimization
//  Distributes workloads across CPU cores without contention
//

import Foundation

/// Thread pool types for different workload categories
enum ThreadPool {
    case main          // Main/game thread (minimal work)
    case renderSubmission  // Render submission thread
    case physics      // Physics thread
    case assetStreaming  // Asset streaming + decompression
    case audio        // Audio thread
    case efficiency   // Efficiency pool (E-cores for non-critical work)
}

/// Job system for explicit thread pool management
class JobSystem {
    static let shared = JobSystem()
    
    // Thread pools
    private let mainQueue = DispatchQueue.main
    private let renderSubmissionQueue: DispatchQueue
    private let physicsQueue: DispatchQueue
    private let assetStreamingQueue: DispatchQueue
    private let audioQueue: DispatchQueue
    private let efficiencyQueue: DispatchQueue
    
    // Performance pool (P-cores) for latency-critical tasks
    private let performanceQueue: DispatchQueue
    
    private init() {
        // Render submission queue (high priority, dedicated thread)
        renderSubmissionQueue = DispatchQueue(
            label: "com.metalracinggame.render",
            qos: .userInteractive,
            attributes: .concurrent
        )
        
        // Physics queue (dedicated thread for physics simulation)
        physicsQueue = DispatchQueue(
            label: "com.metalracinggame.physics",
            qos: .userInitiated,
            attributes: .concurrent
        )
        
        // Asset streaming queue (background work)
        assetStreamingQueue = DispatchQueue(
            label: "com.metalracinggame.assetstreaming",
            qos: .utility,
            attributes: .concurrent
        )
        
        // Audio queue (dedicated for audio processing)
        audioQueue = DispatchQueue(
            label: "com.metalracinggame.audio",
            qos: .userInitiated
        )
        
        // Efficiency queue (E-cores for non-critical work)
        efficiencyQueue = DispatchQueue(
            label: "com.metalracinggame.efficiency",
            qos: .utility,
            attributes: .concurrent
        )
        
        // Performance queue (P-cores for latency-critical tasks)
        performanceQueue = DispatchQueue(
            label: "com.metalracinggame.performance",
            qos: .userInteractive,
            attributes: .concurrent
        )
        
        print("Job System initialized with explicit thread pools")
    }
    
    /// Schedule a job on a specific thread pool
    func scheduleJob(on pool: ThreadPool, async: Bool = true, execute: @escaping () -> Void) {
        let queue: DispatchQueue
        
        switch pool {
        case .main:
            queue = mainQueue
        case .renderSubmission:
            queue = renderSubmissionQueue
        case .physics:
            queue = physicsQueue
        case .assetStreaming:
            queue = assetStreamingQueue
        case .audio:
            queue = audioQueue
        case .efficiency:
            queue = efficiencyQueue
        }
        
        if async {
            queue.async(execute: execute)
        } else {
            queue.sync(execute: execute)
        }
    }
    
    /// Schedule a job on the performance pool (P-cores)
    func schedulePerformanceJob(async: Bool = true, execute: @escaping () -> Void) {
        if async {
            performanceQueue.async(execute: execute)
        } else {
            performanceQueue.sync(execute: execute)
        }
    }
    
    /// Schedule a job on the efficiency pool (E-cores)
    func scheduleEfficiencyJob(async: Bool = true, execute: @escaping () -> Void) {
        if async {
            efficiencyQueue.async(execute: execute)
        } else {
            efficiencyQueue.sync(execute: execute)
        }
    }
    
    /// Execute multiple jobs in parallel on a specific pool
    func scheduleParallelJobs(on pool: ThreadPool, jobs: [() -> Void]) {
        let queue: DispatchQueue
        
        switch pool {
        case .main:
            queue = mainQueue
        case .renderSubmission:
            queue = renderSubmissionQueue
        case .physics:
            queue = physicsQueue
        case .assetStreaming:
            queue = assetStreamingQueue
        case .audio:
            queue = audioQueue
        case .efficiency:
            queue = efficiencyQueue
        }
        
        let group = DispatchGroup()
        for job in jobs {
            group.enter()
            queue.async {
                job()
                group.leave()
            }
        }
        group.wait()
    }
}

