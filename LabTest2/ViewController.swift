//
//  ViewController.swift
//  LabTest2
//
//  Created by Rupika on 2020-05-28.
//  Copyright © 2020 Rupika. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,MKMapViewDelegate,CLLocationManagerDelegate {
    
    
//MARK Outlets
    
    @IBOutlet weak var latTextField: UITextField!
    @IBOutlet weak var longTextField: UITextField!
    @IBOutlet weak var switchLabel: UISwitch!
    @IBOutlet weak var tableViewData: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    
    var startPin: MKPointAnnotation?
    var endPin: MKPointAnnotation?
    var pinIndex = 0
    var userLocation: CLLocationCoordinate2D?
    
    var routeInstructions = [[String]]()
    var travelTimes = [TimeInterval]()
    
    let names = ["A","B","C","D","E","F"]
    let locationManager = CLLocationManager()
    
    let geofenceLimit = 1000
    
    //let currentLocationSimulator = CLLocationCoordinate2D(latitude: 43.7524103, longitude: -79.7824789)
    
    var countPin : [MKPointAnnotation] = [MKPointAnnotation]()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        
    }
    //MARK : Actions
    
    @IBAction func addPinClicked(_ sender: Any) {
        
        if countPin.count < 5 {
            mapView.removeAnnotations(countPin)
            
            
            let getannotation = MKPointAnnotation()
            getannotation.coordinate = CLLocationCoordinate2D(latitude: Double(latTextField.text ?? "") as! CLLocationDegrees, longitude: Double(longTextField.text ?? "") as! CLLocationDegrees)
            countPin.append(getannotation)

            let name = (countPin.count == 0 ) ? names.first : names[countPin.count - 1]
            getannotation.title = name
            mapView.addAnnotations(countPin)
            latTextField.text = ""
            longTextField.text = ""

            let zoomLevel = MKCoordinateSpan(latitudeDelta: 0.5,longitudeDelta: 0.5)
            let region = MKCoordinateRegion(center: countPin.last!.coordinate, span: zoomLevel)
            mapView.setRegion(region, animated: true)

            if countPin.count > 1{
                if startPin == nil {
                    startPin = countPin.first
                }else{
                    startPin = countPin[pinIndex-1]
                }
                endPin = countPin.last
                let locations = countPin.map({$0.coordinate})
                let polyLine = MKPolyline(coordinates:locations, count: countPin.count)
                mapView.addOverlay(polyLine)
                
                getDirections(startPin!.coordinate, endPin!.coordinate, completion: { instructions, distance, expectedTime in
                    self.routeInstructions.append(instructions)
                    self.travelTimes.append(expectedTime)
                    self.tableViewData.reloadData()
                })
                
            }
            
            
        }else{
            showAlert("Limit Reached", "Cannot add any more pins.Please clear the map to add pins again.")
        }
        
        pinIndex += 1
       
    }
    
    func getDirections(_ start: CLLocationCoordinate2D, _ end: CLLocationCoordinate2D, completion:@escaping (([String], Double, TimeInterval) -> Void)){
        
        print("Directions button Pressed")
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate:start))
      
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate:end))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { (response, error) in
            
            
            guard let response = response else{
                print("No directions")
                print("Error")
                return
            }
            print("Directions")
            //43.7155479, -79.7241706 bcc

            var instructions = [String]()
            var distances = [CLLocationDistance]()
            for route in response.routes{
                distances.append(route.distance)
            }
            
            if let shortestDistance = distances.min() {
                print("shortest distance found")
                if let shortestIndex = distances.lastIndex(of: shortestDistance){
                    let route = response.routes[shortestIndex]
                    for step in route.steps{
                        instructions.append(step.instructions)
                    }
                    DispatchQueue.main.async {
                        completion(instructions,shortestDistance,route.expectedTravelTime)
                    }
                }
                
            }
           
        }
    }
    
    
    @IBAction func clearMapClicked(_ sender: Any) {
        mapView.removeAnnotations(countPin)
        mapView.removeOverlays(mapView.overlays)
        countPin.removeAll()
        routeInstructions.removeAll()
        tableViewData.reloadData()
        switchLabel.isOn = false
    }
    
    @IBAction func geoFencingChanged(){
        if switchLabel.isOn {
            //show current location pin
            if let userLocation = userLocation {
                let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                let region = MKCoordinateRegion(center: userLocation, span: span)
                mapView.setRegion(region, animated: true)
                
                let annotation = MKPointAnnotation()
                annotation.coordinate = userLocation
                annotation.title = "Rupika"
                annotation.subtitle = "current location"
                mapView.addAnnotation(annotation)
            }
            
            for pin in countPin {
                checkForGeoFence(pin: pin.coordinate) { (completed) in
                    
                }
            }
           
//            var geoFenceAlertTitles = [String]()
//            for pin in countPin{
//                if let userLocation = userLocation{
//                    let loc1 = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
//                    let loc2 = CLLocation(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
//                    let distance = loc1.distance(from: loc2)
//                    if Int(distance) < geofenceLimit {
//                        geoFenceAlertTitles.append(pin.title!)
//                    }
//                }
//            }
            
//            if geoFenceAlertTitles.count > 0 {
//             //showAlert("Geo fence alert.", "You are in geofence zone for pin \(geoFenceAlertTitles)")
//              view.backgroundColor = .green
//            }else{
//              view.backgroundColor = .white
//            }
            
        }
    }
    
    func checkForGeoFence(pin:CLLocationCoordinate2D, completion:@escaping (Bool) -> Void) {
        if let userLocation = userLocation {
            getDirections(userLocation, pin) { (instructions, distance, expectedTime) in
                if Int(distance) < self.geofenceLimit {
                    DispatchQueue.main.async {
                        self.view.backgroundColor = .green
                    }
                }else{
                    DispatchQueue.main.async {
                        self.view.backgroundColor = .white
                    }
                }
                completion(true)
            }
        }
    }
    
    //3.Draw the polyline on the screen
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        print("Calling the delegate function")
        let render = MKPolylineRenderer(overlay: overlay)
        render.strokeColor = UIColor.red
        render.lineWidth = 5
        return render
    }
    
    func showAlert(_ title: String, _ msg: String){
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        let ok = UIAlertAction(title: "ok", style: .default, handler: nil)
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let instructions = routeInstructions[section]
        return instructions.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return routeInstructions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "myDirectionCell", for: indexPath)
        let instructions = routeInstructions[indexPath.section]
        cell.textLabel?.text = instructions[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        var route = "Driving Directions from \(names[section]) to \(names[section+1])"
        let time = travelTimes[section]
        let label = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        let diplayTime = stringFromTimeInterval(interval: time)
        route = route + "\n" + diplayTime
        label.text = route
        label.isEditable = false
        label.textColor = .white
        label.backgroundColor = UIColor.darkGray
        return label
    }
    
    func stringFromTimeInterval(interval: TimeInterval) -> String {
        
        let ti = NSInteger(interval)
        
        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)
        
        return String(format: "%0.2dh:%0.2dm:%0.2ds",hours,minutes,seconds)
    }
   
    //delegate method for CLLocation
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        userLocation = manager.location!.coordinate
        
        //Have to 3km here. Calculations HOw?
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: userLocation!, span: span)
        mapView.setRegion(region, animated: true)
        
        
        print("current location updated")
    }
}

