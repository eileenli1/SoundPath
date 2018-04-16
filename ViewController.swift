//
//  ViewController.swift
//  MapWithDirections2
//
//  Created by Student on 7/23/17.
//  Copyright © 2017 Patrick Kan. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation
import CoreMotion

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    //@IBOutlet weak var longitudeLabel: UILabel!
    //@IBOutlet weak var latitudeLabel: UILabel!
    //Label for directions
    @IBOutlet weak var directionsLabel: UILabel!
    
    //View of map
    @IBOutlet weak var mapView: MKMapView!
    
    //Search Bar
    @IBOutlet weak var searchBar: UISearchBar!
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    let motionManager = CMMotionManager()
    
    var distance : Double = 0.0
    var angle : Double = 0.0
    
    var count : Int = 1
    
    var musicCount : Int = 0
    var soundName : String = ""
    
    var steps = [MKRouteStep]()
    let speechSynthesizer = AVSpeechSynthesizer()
    
    var latitude : Double?
    var longitude : Double?
    
    var lat : Double?
    var long : Double?
    var foundLocation = false //If a location has already been inputted
    
    var circleCoords : [CLLocationCoordinate2D] = []
    var circleCount = 0
    
    var stepCounter = 0
    
    //Starting Dr J's code -------------------------
    
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
 
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        //Load File into Player
        guard let filePath = Bundle.main.url(forResource: "KennyCleanRecordingDoneNoDelay", withExtension: "wav") else {
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
        
        //locationManager.startUpdatingHeading()
        // We create a helper function to init the sound engine (makes code easier to read and clean)
        initEngine()
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
        
        if(foundLocation)
        {
            let currLoc = CLLocation(latitude: self.latitude!, longitude: self.longitude!)
            
            let nextLoc = CLLocation(latitude: self.circleCoords[self.circleCount].latitude, longitude: self.circleCoords[self.circleCount].longitude)
            
            self.distance = currLoc.distance(from: nextLoc)
            
            // self.distance = self.calculateDistance(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[0].latitude, lon2: self.circleCoords[0].longitude)
            self.angle = self.calculateAngle(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[self.circleCount].latitude, lon2: self.circleCoords[self.circleCount].longitude)
            
            //Try set distance away
            
            let xCoord : Double = 10 * sin(Double.pi*self.angle/180) //Added
            let zCoord : Double = 10 * cos(Double.pi*self.angle/180)
            
            var xTemp = Float(xCoord) //Added
            var zTemp = -1*Float(zCoord)
            self.mixer3d.listenerPosition.z = zTemp
            self.mixer3d.listenerPosition.x = xTemp
            print("Distance is: \(self.distance)")
            print ("z value in space: \(zTemp)")
            print("x value in space: \(xTemp)")
            print("angle: \(self.angle)")

        }
    }
    
    
    func initPositions(){
        mixer3d.listenerPosition.x = 10
        mixer3d.listenerPosition.y = 0
        mixer3d.listenerPosition.z = 10
        
        player.position.x = 0
        player.position.y = 0
        player.position.z = 0
    }
    
    // A function that converts radians to degress in order to use the data from sensors
    func degrees(_ radian: Float) -> Float {
        return (180 * radian / PI)
    }
    
    func radians(degrees: Double) -> Double {
        return (degrees * Double.pi / 180.0)
    }
    
    func receivedOrientationDictionary(_ data: [String:Float]) {
        
        // Retreive the value of the dictionary with the data from sensors
        //let pitch = data["pitch"]
        let yaw = data["yaw"]
        //let roll = data["roll"]
        
        //Change the orientation of the head (mixer3d, our environmentNode)
        //mixer3d.listenerAngularOrientation.pitch  = degrees(pitch!)
        mixer3d.listenerAngularOrientation.yaw = degrees(yaw!)
    }
    
    //End Dr. Martin Jaroszweicz's code -------------------------------
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (CLLocationManager.headingAvailable()) {
            locationManager.headingFilter = 1
            locationManager.startUpdatingHeading()
            locationManager.delegate = self
        }
        
        /*
        motionManager.gyroUpdateInterval = 0.3
        
        motionManager.startGyroUpdates(to: OperationQueue.current!) { (data,error) in
            if let myData = data {
                print(myData.rotationRate) //z axis rotation is the one we want for gps rotation
            }
        } */
        
        //let mag = Magnetometer()
        //mag.runMagnetometer()
        
        //Martin Jaroszewicz's Code -------------------
        
        // Setup an update interval. It varies depending on the application
        motionManager.deviceMotionUpdateInterval = 0.07
        motionManager.gyroUpdateInterval = 0.07
        // We get the values from the IMU as Attitude (Pitch, Roll, Yaw) using a closure
        motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xMagneticNorthZVertical, to: OperationQueue.main) {
            (motion: CMDeviceMotion?, _) in
            
            // Attitude -----------------------------------------------------------
            if let attitude: CMAttitude = motion?.attitude {
                
                //We put the data from sensors in a Dictionary for easy debbuging and sharing (we could delcare d at the top too)
                var d = [String:Float]()
                //d["roll"] = Float(attitude.roll)
                //d["pitch"] = Float(attitude.pitch)
                d["yaw"] = Float(attitude.yaw)
                //print(d)
                // We send the dictionary to a function to keep code clean
                self.receivedOrientationDictionary(d)
                
            }
        }
        /*
         ===============================================================
         End Motion Manager code
         ===============================================================
         */
        
        //End of Martin Jaroszewicz's Code

        
        locationManager.requestAlwaysAuthorization() 
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone //Tracks all movements
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation //May take too much power
        locationManager.pausesLocationUpdatesAutomatically = false //Stops pausing of location updates
        locationManager.startUpdatingLocation() //Begins to update location
        
    }
    
    @IBAction func changeMusic(_ sender: UIButton) {
        musicCount+=1
        //Load File into Player
        switch musicCount {
        case 1 :
            soundName = "Mazurka_Op_67_No_4_In_A_Minor"
        case 2 :
            soundName = "W_A_Mozart_-_Divertimento_No_17_in_D_Major_K_334_Normalized"
        case 3 :
            soundName = "Moses_Chello_normalized"
        case 4 :
            soundName = "KennyCleanRecordingDoneNoDelay"
            musicCount = 0
        default :
            musicCount = 0
        }
        guard let filePath = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
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
        initEngine()
    }
    
    func getDirections(to destination: MKMapItem) {
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let directionsRequest = MKDirectionsRequest()
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = destination
        directionsRequest.transportType = .walking
        
        let directions = MKDirections(request: directionsRequest)
        directions.calculate { (response, _) in
            guard let response = response else { return }
            guard let primaryRoute = response.routes.first else { return }
            
            self.circleCoords.removeAll() //Added
            
            self.mapView.add(primaryRoute.polyline)
                
            self.locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
            
            self.steps = primaryRoute.steps
            for i in 0 ..< primaryRoute.steps.count {
                let step = primaryRoute.steps[i]
                print(step.instructions)
                print(step.distance)
                let region = CLCircularRegion(center: step.polyline.coordinate, radius: 15, identifier: "\(i)")
                self.locationManager.startMonitoring(for: region)
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.add(circle)
                
                self.circleCoords.append(region.center)
                
                print("Latitude of first circle is \(self.circleCoords[0].latitude)")
                print("Longitude of first circle is \(self.circleCoords[0].longitude)")
                
                let currLoc = CLLocation(latitude: self.latitude!, longitude: self.longitude!)
                
                let nextLoc = CLLocation(latitude: self.circleCoords[self.circleCount].latitude, longitude: self.circleCoords[self.circleCount].longitude)
                
                self.distance = currLoc.distance(from: nextLoc)
               
               // self.distance = self.calculateDistance(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[0].latitude, lon2: self.circleCoords[0].longitude)
                self.angle = self.calculateAngle(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[self.circleCount].latitude, lon2: self.circleCoords[self.circleCount].longitude)
                
                //Try set distance away
                
                let xCoord : Double = 10 * sin(Double.pi*self.angle/180) //Added
                let zCoord : Double = 10 * cos(Double.pi*self.angle/180)
                
                var xTemp = Float(xCoord) //Added
                var zTemp = -1*Float(zCoord)
                self.mixer3d.listenerPosition.z = zTemp
                self.mixer3d.listenerPosition.x = xTemp
                print("Distance is: \(self.distance)")
                print ("z value in space: \(zTemp)")
                print("x value in space: \(xTemp)")
                print("angle: \(self.angle)")
            }
            
            self.foundLocation = true
            
            //let initialMessage = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
            
            //self.steps[0].distance for the distance in the first direction
            //self.steps[0].instrutions for the direction the sound should be coming from
            
            //self.directionsLabel.text = initialMessage
            //let speechUtterance = AVSpeechUtterance(string: initialMessage)
            //self.speechSynthesizer.speak(speechUtterance)
            self.stepCounter += 1
        }
    }
    
    
    //Fix
    func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R: Double = 6378.137 // radius of earth in km
        let dLat: Double = lat2*Double.pi/180-lat1*Double.pi/180
        let dLon: Double = lon2*Double.pi/180-lon1*Double.pi/180
        let a: Double = sin(dLat/2)*sin(dLat/2) + cos(lat1*Double.pi/180)*cos(lat2*Double.pi/180)*sin(dLon/2)*sin(dLon/2)
        let c: Double = 2*atan2(sqrt(a), sqrt(1-a))
        let d: Double = R*c
        return d*1000
    }
    
    //Fix
    func calculateAngle(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLon : Double = lon2-lon1
        let y : Double = sin(dLon)*cos(lat2)
        let x : Double = cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(dLon)
        var brng : Float = atan2(Float(y), Float(x))
        brng = degrees(Float(brng))
        brng = (brng + 360).truncatingRemainder(dividingBy: 360)
        brng = 360-brng // count degrees counter-clockwise, remove to make clockwise
        return Double(brng)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //manager.stopUpdatingLocation()
        
        /* let location = locations.last as CLLocation!
         //Uncomment the next two lines for debugging
         //print(location?.coordinate.latitude)
         //print(location?.coordinate.longitude)
         // Get the latitue and longitude !!!
         let latitude = location?.coordinate.latitude
         let longitude = location?.coordinate.longitude
         
         latitudeLabel.text = String(format: "Latitude: %.4f", latitude!)
         longitudeLabel.text = String(format: "Longitude: %.4f", longitude!)
         var loc : CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!,longitude!) */
        //self.locationErrorLabel.isHidden = true
        //let location = locations.last as CLLocation!
        //Uncomment the next two lines for debugging
        //print(location?.coordinate.latitude)
        //print(location?.coordinate.longitude)
        // Get the latitue and longitude !!!
        //let latitude = location?.coordinate.latitude
        //let longitude = location?.coordinate.longitude
        
        //self.latitudeLabel.text = String(format: "Latitude: %.4f", latitude!)
        //self.longitudeLabel.text = String(format: "Longitude: %.4f", longitude!)
        
        guard let currentLocation = locations.last else { return }
        
        currentCoordinate = currentLocation.coordinate
        latitude = currentCoordinate.latitude
        longitude = currentCoordinate.longitude //Longitude and latitude of current coordinate
        //latitudeLabel.text = "Latitude: " + String(latitude!)
        //longitudeLabel.text = "Longitude: " + String(longitude!)
        //print(latitude!)
        //print(longitude!)
        
        if(foundLocation)
        {
            let currLoc = CLLocation(latitude: self.latitude!, longitude: self.longitude!)
            
            let nextLoc = CLLocation(latitude: self.circleCoords[circleCount].latitude, longitude: self.circleCoords[circleCount].longitude)
            
            self.distance = currLoc.distance(from: nextLoc)
            
            // self.distance = self.calculateDistance(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[0].latitude, lon2: self.circleCoords[0].longitude)
            self.angle = self.calculateAngle(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[circleCount].latitude, lon2: self.circleCoords[circleCount].longitude)
            
            let xCoord : Double = 10 * sin(Double.pi*self.angle/180.0) //Added
            let zCoord : Double = 10 * cos(Double.pi*self.angle/180.0)
            
            var xTemp = Float(xCoord) //Added
            var zTemp = -1*Float(zCoord)
            self.mixer3d.listenerPosition.z = zTemp
            self.mixer3d.listenerPosition.x = xTemp
            print("Distance is: \(self.distance)")
            print ("z value in space: \(zTemp)")
            print("x value in space: \(xTemp)")
            print("angle: \(self.angle)")
        }
        
        mapView.userTrackingMode = .followWithHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        print (heading.magneticHeading) //Prints compass direction
        let angle = heading.magneticHeading
        if(angle < 180)
        {
            self.mixer3d.listenerAngularOrientation.yaw = Float(-1*angle)
        }
        else
        {
            self.mixer3d.listenerAngularOrientation.yaw = Float(360-angle)
        }

    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("ENTERED")
        stepCounter += 1
        circleCount += 1
        if stepCounter < steps.count {
            let currentStep = steps[stepCounter]
            //let message = "In \(currentStep.distance) meters, \(currentStep.instructions)"
            //directionsLabel.text = message
            if(circleCount < circleCoords.count) {
                
                print("Latitude of circle is \(self.circleCoords[circleCount].latitude)")
                print("Longitude of circle is \(self.circleCoords[circleCount].longitude)")
                
                let currLoc = CLLocation(latitude: self.latitude!, longitude: self.longitude!)
                
                let nextLoc = CLLocation(latitude: self.circleCoords[circleCount].latitude, longitude: self.circleCoords[circleCount].longitude)
                
                self.distance = currLoc.distance(from: nextLoc)
                
                // self.distance = self.calculateDistance(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[0].latitude, lon2: self.circleCoords[0].longitude)
                self.angle = self.calculateAngle(lat1: self.latitude!, lon1: self.longitude!, lat2: self.circleCoords[circleCount].latitude, lon2: self.circleCoords[circleCount].longitude)
                
                let xCoord : Double = 10 * sin(Double.pi*self.angle/180.0) //Added
                let zCoord : Double = 10 * cos(Double.pi*self.angle/180.0)
                
                var xTemp = Float(xCoord) //Added
                var zTemp = -1*Float(zCoord)
                self.mixer3d.listenerPosition.z = zTemp
                self.mixer3d.listenerPosition.x = xTemp
                print("Distance is: \(self.distance)")
                print ("z value in space: \(zTemp)")
                print("x value in space: \(xTemp)")
                print("angle: \(self.angle)")
            }
            else
            {
                print("Count went over array size")
            }
            //let speechUtterance = AVSpeechUtterance(string: message)
            //speechSynthesizer.speak(speechUtterance)
        } else {
            let message = "Arrived at destination"
            player.pause()
            //directionsLabel.text = message
            //let speechUtterance = AVSpeechUtterance(string: message)
            //speechSynthesizer.speak(speechUtterance)
            stepCounter = 0
            locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
            
        }
    }
    
}
/*
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //manager.stopUpdatingLocation()
        
        /* let location = locations.last as CLLocation!
         //Uncomment the next two lines for debugging
         //print(location?.coordinate.latitude)
         //print(location?.coordinate.longitude)
         // Get the latitue and longitude !!!
         let latitude = location?.coordinate.latitude
         let longitude = location?.coordinate.longitude
         
         latitudeLabel.text = String(format: "Latitude: %.4f", latitude!)
         longitudeLabel.text = String(format: "Longitude: %.4f", longitude!)
         var loc : CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!,longitude!) */
        //self.locationErrorLabel.isHidden = true
        //let location = locations.last as CLLocation!
        //Uncomment the next two lines for debugging
        //print(location?.coordinate.latitude)
        //print(location?.coordinate.longitude)
        // Get the latitue and longitude !!!
        //let latitude = location?.coordinate.latitude
        //let longitude = location?.coordinate.longitude
        
        //self.latitudeLabel.text = String(format: "Latitude: %.4f", latitude!)
        //self.longitudeLabel.text = String(format: "Longitude: %.4f", longitude!)
        
        guard let currentLocation = locations.last else { return }
        
        currentCoordinate = currentLocation.coordinate
        latitude = currentCoordinate.latitude
        longitude = currentCoordinate.longitude //Longitude and latitude of current coordinate
        latitudeLabel.text = "Latitude: " + String(latitude!)
        longitudeLabel.text = "Longitude: " + String(longitude!)
        print(latitude!)
        print(longitude!)
        
        mapView.userTrackingMode = .followWithHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        print (heading.magneticHeading) //Prints compass direction
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("ENTERED")
        stepCounter += 1
        if stepCounter < steps.count {
            let currentStep = steps[stepCounter]
            let message = "In \(currentStep.distance) meters, \(currentStep.instructions)"
            directionsLabel.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        } else {
            let message = "Arrived at destination"
            directionsLabel.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
            stepCounter = 0
            locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
            
        }
    }
}
*/
//Search Bar
extension ViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        let localSearchRequest = MKLocalSearchRequest()
        localSearchRequest.naturalLanguageQuery = searchBar.text
        let overlays = self.mapView.overlays
        self.mapView.removeOverlays(overlays)
        let region = MKCoordinateRegion(center: currentCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        localSearchRequest.region = region
        let localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.start { (response, _) in
            guard let response = response else { return }
            guard let firstMapItem = response.mapItems.first else { return }
            self.getDirections(to: firstMapItem)
            self.circleCount = 0
        }
        
    }
}

extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .purple
            renderer.lineWidth = 10
            return renderer
        }
        
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            renderer.fillColor = .red
            renderer.alpha = 0.5
            return renderer
        }
        return MKOverlayRenderer()
    }
}
