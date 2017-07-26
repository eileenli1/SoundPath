//
//  ViewController.swift
//  3daudio2
//
//  Created by Eileen Li on 7/25/17.
//  Copyright © 2017 Eileen Li. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion

class ViewController: UIViewController {
    
    // Declare out own Pi for doing operations with angles
    let PI : Float = 3.14159265359
    
    /*
     ===========================================================================================
     We need to create a signal flow connecting the nodes: Source -> Mixer3D -> Mixer -> Output
     ===========================================================================================
     */
    // Audio engine for managing all audio
    var engine: AVAudioEngine!
    /*
     ======================================================================================================
     We create a source: A player system that is built with a path, a file, a buffer, and a player node
     ======================================================================================================
     */
    // A file
    var file:  AVAudioFile!
    // A buffer to store our audio file
    var buffer: AVAudioPCMBuffer!
    // A player to play our sound file
    var player:  AVAudioPlayerNode!
    /*
     ======================================================================================================
     We declared the source player
     ======================================================================================================
     */
    // We need an output node
    var output: AVAudioOutputNode!
    // A mixer node to send all sounds
    var mixer: AVAudioMixerNode!
    // A mixer 3D to send sounds that we want to spatialize and locate them at a point in a 3D space
    var mixer3d: AVAudioEnvironmentNode!
    
    //var multiChannelOutputEnable: Bool!
    
    // We can select an algorithm for spatialization: 1 = Spherical Head, 2 = Head Related Transfer Function (HRTF)
    var selectedAlgorithm: Int!
    // To store an arbitraty orietn
    
    //var orientation = AVAudioMake3DAngularOrientation(0.0,0.0,0.0)
    /*
     ===========================================================================================
     We are going to use the built-in IMU (Accelerometer, Gyroscope, Magnetometer
     ===========================================================================================
     */
    var motionManager : CMMotionManager!
    
    
    //let center = NotificationCenter()
    //var isPlaying: Bool = false
   
    override func viewDidAppear(_ animated: Bool) {
        
        //Load File into Player
        guard let filePath = Bundle.main.url(forResource: "ZOOM0001_Tr1", withExtension: "WAV") else {
            print("Cannot find file")
            return
        }
        do {
            file = try AVAudioFile(forReading: filePath)
        }
        catch {
            print("Cannot load audiofile!")
        }
        // We need the following two statements to use our buffer object
        let audioFormat = file.processingFormat
        let audioFrameCount = UInt32(file.length)
        // we create an instance of the buffer
        buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        do {
            try file.read(into: buffer, frameCount: audioFrameCount)
            print("File loaded")
        }
        catch{
            print("Could not load file into buffer")
        }
        
        
        // We create a helper function to init the sound engine (makes code easier to read and clean)
        initEngine()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         ===============================================================
         Motion MAnager. Get sesnsor data and store it in a Dictionary
         ===============================================================
         */
        
        // Create an instance of the motionManager
        motionManager = CMMotionManager()
        // Setup an update interval. It varies depending on the application
        motionManager.deviceMotionUpdateInterval = 1/10.0
        motionManager.gyroUpdateInterval = 0.1
        // We get the values from the IMU as Attitude (Pitch, Roll, Yaw) using a closure
        motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical, to: OperationQueue.main) {
            (motion: CMDeviceMotion?, _) in
            
            // Attitude -----------------------------------------------------------
            if let attitude: CMAttitude = motion?.attitude {
                
                //We put the data from sensors in a Dictionary for easy debbuging and sharing (we could delcare d at the top too)
                var d = [String:Float]()
                d["roll"] = Float(attitude.roll)
                d["pitch"] = Float(attitude.pitch)
                d["yaw"] = Float(attitude.yaw)
                print(d)
                // We send the dictionary to a function to keep code clean
                self.receivedOrientationDictionary(d)
                
            }
        }
        /*
         ===============================================================
         End Motion MAnager code
         ===============================================================
         */
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initEngine(){
        
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        mixer3d = AVAudioEnvironmentNode()
        // Helper function to initialize the player (source) and head (mixer3D or EnvironmentNode)
        initPositions()//(mixer3d, playerPosition: player)
        
        // Here we connect the nodes following a signal flow chain
        mixer = engine.mainMixerNode
        engine.attach(player)
        engine.attach(mixer3d)
        player.renderingAlgorithm = AVAudio3DMixingRenderingAlgorithm(rawValue: 2)!
        engine.connect(player, to: mixer3d, format: file.processingFormat)
        engine.connect(mixer3d, to: mixer, format: mixer3d.outputFormat(forBus: 0))
        
        let loop = AVAudioPlayerNodeBufferOptions.loops
        player.scheduleBuffer(buffer, at: nil, options: loop, completionHandler: nil)
        do {
            try engine.start()
        }
        catch {
            print("Cannot initialize engine")
        }
        player.play()
    }
    
    
    func initPositions(){
        mixer3d.listenerPosition.x = 0
        mixer3d.listenerPosition.y = 0
        mixer3d.listenerPosition.z = 0
        
        player.position.x = 0
        player.position.y = 0
        player.position.z = 0
    }
    @IBAction func slider(_ sender: UISlider) {
        switch sender.tag{
        case 0:
            mixer3d.listenerAngularOrientation.yaw = sender.value*360
        case 1:
            player.position.z = sender.value*10
        case 2:
            //player.position.y = sender.value*2-1
            mixer3d.listenerAngularOrientation.pitch = sender.value*90-45
        default: break
            //Do nothing
        }

    }
    // A function that converts radians to degress in order to use the data from sensors
    func degrees(_ radian: Float) -> Float {
        return (180 * radian / PI)
    }
    
    func receivedOrientationDictionary(_ data: [String:Float]) {
        
        // Retreive the value of the dictionary with the data from sensors
        let pitch = data["pitch"]
        let yaw = data["yaw"]
        let roll = data["roll"]
        
        //Change the orientation of the head (mixer3d, our environmentNode)
        mixer3d.listenerAngularOrientation.pitch  = degrees(pitch!)
        mixer3d.listenerAngularOrientation.yaw = degrees(yaw!)
    }
    
}

