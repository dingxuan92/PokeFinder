//
//  ViewController.swift
//  PokeFinder
//
//  Created by Chan Ding Xuan on 28/12/16.
//  Copyright © 2016 Chan Ding Xuan. All rights reserved.
//

import UIKit
import MapKit
import FirebaseDatabase

class ViewController: UIViewController,MKMapViewDelegate, CLLocationManagerDelegate {
    

    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var geoFire: GeoFire!
    var mapHasCenteredOnce = false
    var geoFireRef: FIRDatabaseReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        mapView.userTrackingMode = MKUserTrackingMode.follow
        
        geoFireRef = FIRDatabase.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus()
    }
    
    func locationAuthStatus() {
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            
            //authorizedWhenInUse does not drain user battery
            mapView.showsUserLocation = true
        } else {
            
            locationManager.requestWhenInUseAuthorization()
            
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedWhenInUse {
            
            mapView.showsUserLocation = true
            
        }
    }
    
    func centerMapOnLocation(location: CLLocation) {
        
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 2000)
        
        mapView.setRegion(coordinateRegion, animated: true)
        
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        //center the map after GPS updates when following the user
        
        if let loc = userLocation.location {
            
            if !mapHasCenteredOnce {
                
                centerMapOnLocation(location: loc)
                mapHasCenteredOnce = true
                
            }
            
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        //create a sighting, plotting the pokemon onto the map (customize the pin to pokemon)
        
        var annotationView:MKAnnotationView?
        let annoIdentifier = "Pokemon"
        
        if annotation.isKind(of: MKUserLocation.self) {
            
            //set user annotation as ash
            
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            
            annotationView?.image = UIImage(named: "ash")
            
        } else if let deqAnno = mapView.dequeueReusableAnnotationView(withIdentifier: annoIdentifier) {
            
            annotationView = deqAnno
            annotationView?.annotation = annotation
            
        } else {
            
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: annoIdentifier)
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = av
        }
        
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation {
            
            annotationView.canShowCallout = true // have to set title if not will crash
            annotationView.image = UIImage(named: "\(anno.pokemonNumber)")
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named:"map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
        }
        
        
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        showSightingsOnMap(location: loc)
    }
    
    func createSighting(forLocation location:CLLocation, withPokemon pokeId: Int) {
        
        geoFire.setLocation(location, forKey: "\(pokeId)")
        //when this happens, it will go to the circleQuery?.observe below. It will call it as many times as you add the pokemons
        
    }
    
    func showSightingsOnMap(location: CLLocation) {
        
        let circleQuery = geoFire!.query(at:location, withRadius: 2.5)
        
        _ = circleQuery?.observe(GFEventType.keyEntered, with: { (key, location) in
            
            //Also, as when the app loads for the first time, the this will run and cycle through every single pokemon on the map, with its specific geographic location and going to add it as annotation
            
            if let key = key, let location = location {
                
                let anno = PokeAnnotation(coordinate: location.coordinate, pokemonNumber: Int(key)!)
                
                self.mapView.addAnnotation(anno)
                
            }
        })
        
        
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let anno = view.annotation as? PokeAnnotation {
            
            var place: MKPlacemark!
            if #available(iOS 10.0, *) {
                place = MKPlacemark(coordinate: anno.coordinate)
            } else {
                place = MKPlacemark(coordinate: anno.coordinate, addressDictionary: nil)
            }
            
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon Sighting"
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span),MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
        
    }

    @IBAction func spotRandomPokemon(_ sender: Any) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        let rand = arc4random_uniform(151) + 1
        
        createSighting(forLocation: loc, withPokemon: Int(rand))
        
        // when spotted a pokemon, call function createSighting
        
        
    }

}

