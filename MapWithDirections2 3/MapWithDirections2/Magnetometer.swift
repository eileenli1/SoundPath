//
//  Magnetometer.swift
//  MapWithDirections2
//
//  Created by Student on 7/24/17.
//  Copyright © 2017 Patrick Kan. All rights reserved.
//

import UIKit
import CoreLocation

class Magnetometer: UIViewController, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    
    func runMagnetometer() {
        if (CLLocationManager.headingAvailable()) {
            locationManager.headingFilter = 1
            locationManager.startUpdatingHeading()
            locationManager.delegate = self
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        print (heading.magneticHeading)
    }
    
}

