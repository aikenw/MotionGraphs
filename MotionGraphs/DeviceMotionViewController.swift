/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A view controller to display output from the motion sensor.
 */

import UIKit
import CoreMotion
import simd

extension Date {
    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: self)
    }
}

class DeviceMotionViewController: UIViewController, MotionGraphContainer {
    
    // MARK: Properties
    
    @IBOutlet var graphSelector: UISegmentedControl!
    
    @IBOutlet var graphsContainer: UIView!
    
    private var selectedDeviceMotion: DeviceMotion {
        return DeviceMotion(rawValue: graphSelector.selectedSegmentIndex)!
    }
    
    private var graphViews: [GraphView] = []

    // MARK: MotionGraphContainer properties
    
    var motionManager: CMMotionManager?

    @IBOutlet weak var updateIntervalLabel: UILabel!
    
    @IBOutlet weak var updateIntervalSlider: UISlider!
    
    let updateIntervalFormatter = MeasurementFormatter()
    
    @IBOutlet var valueLabels: [UILabel]!
    
    var startTime = Date()
    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create graph views for each graph type.
        graphViews = DeviceMotion.allTypes.map { type in
            return GraphView(frame: graphsContainer.bounds)
        }
        
        // Add the graph views to the container view.
        for graphView in graphViews {
            graphsContainer.addSubview(graphView)
            graphView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        startTime = Date()
        startUpdates()
        startAccelerometerUpdates()
        startGyroscopeUpdates()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopUpdates()
        stopAccelerometerUpdates()
        stopGyroscopeUpdates()
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func intervalSliderChanged(_ sender: UISlider) {
        startUpdates()
    }
    
    @IBAction func graphSelectorChanged(_ sender: UISegmentedControl) {
        showGraph(selectedDeviceMotion)
    }
    
    // MARK: MotionGraphContainer implementation
    
    private lazy var deviceMotionLogger = Logger(fileName: "\(startTime.fileName)_deviceMotion.txt")
    func startUpdates() {
        guard let motionManager = motionManager, motionManager.isDeviceMotionAvailable else { return }
        
        showGraph(selectedDeviceMotion)
        updateIntervalLabel.text = formattedUpdateInterval
        
        motionManager.deviceMotionUpdateInterval = TimeInterval(updateIntervalSlider.value)
        motionManager.showsDeviceMovementDisplay = true
        
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { deviceMotion, error in
            guard let deviceMotion = deviceMotion else { return }
            
            let attitude = double3([deviceMotion.attitude.roll, deviceMotion.attitude.pitch, deviceMotion.attitude.yaw])
            self.deviceMotionLogger.append(line: "timestamp: \(deviceMotion.timestamp), roll: \(deviceMotion.attitude.roll), pitch: \(deviceMotion.attitude.pitch), yaw: \(deviceMotion.attitude.yaw)")
            let rotationRate = double3([deviceMotion.rotationRate.x, deviceMotion.rotationRate.y, deviceMotion.rotationRate.z])
            let gravity = double3([deviceMotion.gravity.x, deviceMotion.gravity.y, deviceMotion.gravity.z])
            let userAcceleration = double3([deviceMotion.userAcceleration.x, deviceMotion.userAcceleration.y, deviceMotion.userAcceleration.z])
//
            self.graphView(for: .attitude).add(attitude)
//            self.graphView(for: .rotationRate).add(rotationRate)
//            self.graphView(for: .gravity).add(gravity)
//            self.graphView(for: .userAcceleration).add(userAcceleration)
            
            // Update the labels with data for the currently selected device motion.
            switch self.selectedDeviceMotion {
            case .attitude:
                self.setValueLabels(rollPitchYaw: attitude)

            case .rotationRate:
                self.setValueLabels(xyz: rotationRate)

            case .gravity:
                self.setValueLabels(xyz: gravity)

            case .userAcceleration:
                self.setValueLabels(xyz: userAcceleration)
            }
        }
    }

    func stopUpdates() {
        guard let motionManager = motionManager, motionManager.isDeviceMotionActive else { return }

        motionManager.stopDeviceMotionUpdates()
        deviceMotionLogger.save()
    }
    
    // Accelerometer
    private lazy var accelerometerLogger = Logger(fileName: "\(startTime.fileName)_accelerometers.txt")
    func startAccelerometerUpdates() {
        guard let motionManager = motionManager, motionManager.isAccelerometerAvailable else { return }
        
//        updateIntervalLabel.text = formattedUpdateInterval
        
        motionManager.accelerometerUpdateInterval = TimeInterval(updateIntervalSlider.value)
        motionManager.showsDeviceMovementDisplay = true
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] accelerometerData, error in
            guard let accelerometerData = accelerometerData else { return }
            
            let acceleration: double3 = [accelerometerData.acceleration.x, accelerometerData.acceleration.y, accelerometerData.acceleration.z]
            self?.accelerometerLogger.append(line: "timestamp: \(accelerometerData.timestamp), x: \(accelerometerData.acceleration.x), y: \(accelerometerData.acceleration.y), z: \(accelerometerData.acceleration.z)")
        }
    }
    
    func stopAccelerometerUpdates() {
        guard let motionManager = motionManager, motionManager.isAccelerometerAvailable else { return }
        
        motionManager.stopAccelerometerUpdates()
        accelerometerLogger.save()
    }
    
    // Gyroscope
    private lazy var gyroscopeLogger = Logger(fileName: "\(startTime.fileName)_gyroscope.txt")
    func startGyroscopeUpdates() {
        guard let motionManager = motionManager, motionManager.isGyroAvailable else { return }
        
        updateIntervalLabel.text = formattedUpdateInterval
        
        motionManager.gyroUpdateInterval = TimeInterval(updateIntervalSlider.value)
        motionManager.showsDeviceMovementDisplay = true
        
        motionManager.startGyroUpdates(to: .main) { [weak self] gyroData, error in
            guard let gyroData = gyroData else { return }
            
            let rotationRate: double3 = [gyroData.rotationRate.x, gyroData.rotationRate.y, gyroData.rotationRate.z]
            self?.gyroscopeLogger.append(line: "timestamp: \(gyroData.timestamp), x: \(gyroData.rotationRate.x), y: \(gyroData.rotationRate.y), y: \(gyroData.rotationRate.z)")
        }
    }
    
    func stopGyroscopeUpdates() {
        guard let motionManager = motionManager, motionManager.isAccelerometerAvailable else { return }
        
        motionManager.stopGyroUpdates()
        gyroscopeLogger.save()
    }
    
    // MARK: Convenience
    
    private func graphView(for motionType: DeviceMotion) -> GraphView {
        let index = motionType.rawValue
        return graphViews[index]
    }
    
    private func showGraph(_ motionType: DeviceMotion) {
        let selectedGraphIndex = motionType.rawValue
        
        for (index, graph) in graphViews.enumerated() {
            graph.isHidden = index != selectedGraphIndex
        }
    }
}


fileprivate enum DeviceMotion: Int {
    case attitude, rotationRate, gravity, userAcceleration
    
    static let allTypes: [DeviceMotion] = [.attitude, .rotationRate, .gravity, .userAcceleration]
}
