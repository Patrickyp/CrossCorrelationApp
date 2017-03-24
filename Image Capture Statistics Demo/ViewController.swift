//
//  ViewController.swift
//  Image Capture Statistics Demo
//
//  Created by Patrick Pan on 11/28/16.
//  Copyright © 2016 3srm. All rights reserved.
//
// Camera feed code from: https://www.youtube.com/watch?v=uUTevJAhL3Q&spfreload=10
//
// ScrollView tutorial: https://www.youtube.com/watch?v=rjTS9fyWqdg&t=176s

import UIKit
import AVFoundation
import CoreLocation
import CoreMotion
import SwiftyDropbox


class ViewController: UIViewController, UIImagePickerControllerDelegate, CLLocationManagerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate  {
    
    var methodStart : Date?
    var ImageFunc = ImageFunctions()
    
    // ******************** For Crosscorrelation **********
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var tempImageView: UIImageView!
    @IBOutlet var imageView1: UIImageView!
    @IBOutlet var imageView2: UIImageView!
    @IBOutlet var cameraSwitch: UISwitch!
    
    var image1Data: UIImage?
    var image2Data: UIImage?
    
    var captureSession : AVCaptureSession?
    var previewLayer : AVCaptureVideoPreviewLayer?
    
    // Store captured images in this array
    var capturedImages = [UIImage?](repeating: nil, count:10)
    var capturedImagesStatistics = Array(repeating: "", count:10)
    
    // Store this as global to change zoom level
    var backCamera: AVCaptureDevice? = nil
    
    // ******************* For Statistics *****************
    @IBOutlet var dirLabel: UILabel!
    @IBOutlet var longLabel: UILabel!
    @IBOutlet var latLabel: UILabel!
    @IBOutlet var altLabel: UILabel!
    @IBOutlet var pressureLabel: UILabel!
    @IBOutlet var pitchLabel: UILabel!
    @IBOutlet var yawLabel: UILabel!
    @IBOutlet var rollLabel: UILabel!
    
    @IBOutlet var distanceTextField: UITextField!
    @IBOutlet var lastestVelocityLabel: UILabel!
    
    //start CLLocationManager object for long/lat/alt
    let locationManager = CLLocationManager()
    //start CMMotionManager object for tilt
    let motionManager = CMMotionManager()
    //start CMAltimeter for pressure
    let altimeter = CMAltimeter()
    
    // ******************** For Dropbox ********************
    @IBOutlet var dropboxSignInButton: UIButton!
    @IBOutlet var signedInStatusLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager.delegate = self
        
        //set up location initialization
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        
        //set up direction initialization
        self.locationManager.startUpdatingHeading()
        
        // For checking if user is logged into dropbox
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.handleDidLinkNotification), name: NSNotification.Name(rawValue: "didLinkToDropboxAccountNotification"), object: nil)
        
        // Used to dismiss keyboard on tap
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        activityIndicator.hidesWhenStopped = true
        
        startTilt()
        startAltimeter()
        startSession()
    }
    
    // There is a bug that will display an image over the imageview if sign in is tapped while live camera mode is on (opacity = 1).  This is a temporary workaround.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.previewLayer?.opacity = 0
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = tempImageView.bounds
        
        // This is needed since we have to recheck after user returns from sign in
        if cameraSwitch.isOn {
            self.previewLayer?.opacity = 1
        } else {
            self.previewLayer?.opacity = 0
        }
        
        // If already signed in when view appears, update label and button
        if (DropboxClientsManager.authorizedClient != nil) {
            self.dropboxSignInButton.setTitle("Sign Out", for: .normal)
            signedInStatusLabel.isHidden = true
        }
    }
    
    
    @IBAction func takeImage(_ sender: UIButton) {
        
        // Check that the distance textfield is not empty i.e. user entered a distance
        if let text = distanceTextField.text, !text.isEmpty {
            //self.tempImageView.image = UIImage(named: "placeholder")
            //TODO
            self.activityIndicator.startAnimating()
            recording = true
        } else {
            // If distance box is empty, stop updating and alert the user
            let alertView = UIAlertView(title: "Error", message: "No distance entered!  Tap box next to the distance label to enter a distance from target.", delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
        }
        
    }
    
    // Switch to turn on/off the live camera feed.
    @IBAction func showLiveCameraFeed(_ sender: UISwitch) {
        if cameraSwitch.isOn {
            self.previewLayer?.opacity = 1
        } else {
            self.previewLayer?.opacity = 0
        }
    }
    
    //Set zoom of camera and preview
    @IBAction func setZoomButton(_ sender: UIButton) {
        if backCamera != nil {
            if let txt = sender.currentTitle {
                do {
                    if txt == "1x" {
                        try backCamera?.lockForConfiguration()
                        let zoomFactor:CGFloat = 2
                        backCamera?.videoZoomFactor = zoomFactor
                        backCamera?.unlockForConfiguration()
                        sender.setTitle("2x", for: .normal)
                    }
                    else {
                        try backCamera?.lockForConfiguration()
                        let zoomFactor:CGFloat = 1
                        backCamera?.videoZoomFactor = zoomFactor
                        backCamera?.unlockForConfiguration()
                        sender.setTitle("1x", for: .normal)
                    }
                } catch {
                    
                }
            }
        }
    }
    
    func getCurrentMillis() {
        let t = Int64(Date().timeIntervalSince1970 * 1000)
        print("\(t)")
    }
    
    // Calls crossCorrelationResult C++ function in another thread, gets the returned image and
    // update main UIImageView in main thread.
    func crossCorrelateImages(imageArr:[UIImage], completionHandler: @escaping (_: UIImage) -> Void){
        
        // Move to a background thread to call the find template function
        DispatchQueue.global(qos: .userInitiated).async {
            // Get user input from distance field.  No need to check since we did in takeImage function.
            let distanceInput = self.distanceTextField.text!
            let distanceDecimal = Double(distanceInput)!
            var velocity = 0.0 // passed to findTemplate function as pointer
            
            let NSImageArray:[Any] = imageArr
            
            // *****************Call our xcorr c++ function************.
            var crossCorrelationResult = OpenCVWrapper.findTemplatev2(NSImageArray, distanceFromTarget: distanceDecimal, calculatedVelocity: &velocity)
            
            // The result UIImage with arrows is passed to completionHandler.  It is the caller's job to implement completion handling.
            completionHandler(crossCorrelationResult!)
            
            // Move back to main thread to update UI
            DispatchQueue.main.async {
                self.lastestVelocityLabel.text = String(format: "Latest Velocity: %.03fm/s", velocity)
                // Rotate image back before showing in imageview since all images were rotated before saving.
                crossCorrelationResult = UIImage(cgImage: crossCorrelationResult!.cgImage!, scale: 1.0, orientation: UIImageOrientation.up)
                self.tempImageView.image = crossCorrelationResult
                self.activityIndicator.stopAnimating()
                print("crosscorrelate done!")
            }
        }
    }
    
    func startSession(){
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        backCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        // Catch error using the do catch block
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if (captureSession?.canAddInput(input) != nil){
                captureSession?.addInput(input)
                
                // Setup the preview layer
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                tempImageView.layer.addSublayer(previewLayer!)
                captureSession?.startRunning()
                // Set up AVCaptureVideoDataOutput
                let dataOutput = AVCaptureVideoDataOutput()
                dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
                dataOutput.alwaysDiscardsLateVideoFrames = true
                
                if (captureSession?.canAddOutput(dataOutput) == true) {
                    captureSession?.addOutput(dataOutput)
                }
                let queue = DispatchQueue(label: "edu.hawaii.yuep.videoQueue")
                dataOutput.setSampleBufferDelegate(self, queue: queue)
            }
        } catch _ {
            print("Error setting up camera!")
        }
    }
    
    func writeStatisticToImage(image:UIImage) -> UIImage{
        
        var stats = ""
        stats += dirLabel.text!
        stats += "\n"
        stats += longLabel.text!
        stats += "\n"
        stats += latLabel.text!
        stats += "\n"
        stats += altLabel.text!
        stats += "\n"
        stats += pressureLabel.text!
        stats += "\n"
        stats += pitchLabel.text!
        stats += "\n"
        stats += yawLabel.text!
        stats += "\n"
        stats += rollLabel.text!
        
        let finalImage = ImageFunc.textToImage(drawText: stats as NSString, inImage: image, atPoint: CGPoint(x: 20, y: 20))
        //let finalImage = textToImage(drawText: stats as NSString, inImage: image, atPoint: CGPoint(x: 20, y: 20))
        return finalImage
    }
    
    var recording = false
    var imageArray = [UIImage]()
    
    var startTime: NSDate? = nil
    var stopTime: NSDate? = nil
    
    var delayType = "short"
    var skipCount = 0
    var imageSaved = 0
    
    let numberOfImageToSave = 10
    
    
    // MARK: - Capture frame delegate.
    
    // test variables
    var count = 0
    
    // ******************* VideoDataCapture Delegate Methods **********************
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {

        if (recording == true) {
            // First frame, start timer and save frame to array.
            if (imageSaved == 0) {
                startTime = NSDate()
                // Convert from sampleBuffer to UIImage
                var image = ImageFunc.sampleBufferToUIImage(sampleBuffer: sampleBuffer)
                // Rotate image
                image = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: UIImageOrientation.right)
                // Write statistics text to image
                //let statsImage = writeStatisticToImage(image: image)
                imageArray.append(image)
                imageSaved+=1
            }
            else if (delayType == "short") {
                if (skipCount >= 2) {
                    delayType = "long"
                    var image = ImageFunc.sampleBufferToUIImage(sampleBuffer: sampleBuffer)
                    image = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: UIImageOrientation.right)
                    imageArray.append(image)
                    imageSaved+=1
                    skipCount = 0
                } else {
                    skipCount+=1
                }
            }
            else if (delayType == "long") {
                if (skipCount >= 14) {
                    delayType = "short"
                    var image = ImageFunc.sampleBufferToUIImage(sampleBuffer: sampleBuffer)
                    image = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: UIImageOrientation.right)
                    imageArray.append(image)
                    imageSaved+=1
                    skipCount = 0
                } else {
                    skipCount+=1
                }
            }
            
            // Check if desired number of images are saved already.
            if (imageSaved >= numberOfImageToSave) {
                
                stopTime = NSDate()
                let timeInterval: Double = (stopTime?.timeIntervalSince(startTime as! Date))!
                print("\nTime Interval = \(timeInterval)\nTotal images recorded: \(imageArray.count)\nimageSaved = \(imageSaved)")
                
                
                DispatchQueue.main.sync {
                    self.imageView1.image = self.imageArray[0]
                    self.imageView2.image = self.imageArray[1]
                    // Save original images to library
                    //self.saveImagesToLibrary(imageArray: self.imageArray)
                    ImageFunc.saveImagesToLibrary(imageArray: self.imageArray)
                }
                
                self.crossCorrelateImages(imageArr: imageArray, completionHandler: {(arrowedImage:UIImage) -> Void in
                    print("XCorr done!")
                })
                
                imageArray.removeAll()
                imageSaved = 0
                skipCount = 0
                recording = false
                delayType = "short"
                
            }
        }
        
    }
    
    
    
    /********************* Delegates for Statistics *********************/
    
    //delegate method, constantly read latitutde and longitutde
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        //get the lat/long/alt values
        let long = userLocation.coordinate.longitude;
        let lat = userLocation.coordinate.latitude;
        let alt = userLocation.altitude
        
        latLabel.text = String(format: "Latitude: %.09f", lat)
        longLabel.text = String(format: "Longitude: %.09f", long)
        altLabel.text = String(format: "Altitude: %.09f", alt)
        
    }
    
    //delegate method, if locationmanager fails?
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error: " + error.localizedDescription)
    }
    
    //delegate method, constantly print out direction in degrees (0-360) when changed
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.magneticHeading
        //print(heading)
        dirLabel.text = String(format: "Direction: %.02f", heading)
    }
    
    func startTilt(){
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler:{
            deviceManager, error in
            //do the following when we get a DeviceMotionUpdate
            
            //Do stuffs with deviceManager or with error
            let attitude = deviceManager?.attitude
            let pitch = attitude?.pitch
            self.pitchLabel.text = String(format: "Pitch: %.03f", pitch!)
            let roll = attitude?.roll
            self.rollLabel.text = String(format: "Roll: %.03f", roll!)
            let yaw = attitude?.yaw
            self.yawLabel.text = String(format: "Yaw: %.03f", yaw!)
        })
        
    }
    
    //function to start Altimeter and collect pressure data.  Called in ViewDidLoad.
    func startAltimeter() {
        
        // Check if altimeter feature is available
        if (CMAltimeter.isRelativeAltitudeAvailable()) {
            
            //self.activityIndicator.startAnimating()
            
            // Start altimeter updates, add it to the main queue
            self.altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: { (altitudeData:CMAltitudeData?, error:Error?) in
                
                if (error != nil) {
                    
                    // If there's an error, stop updating and alert the user
                    let alertView = UIAlertView(title: "Error", message: error!.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
                    alertView.show()
                    
                } else {
                    //print("outputting data...")
                    
                    //let altitude = altitudeData!.relativeAltitude.floatValue    // Relative altitude in meters
                    let pressure = altitudeData!.pressure.floatValue * 10.0           // Pressure in kilopascals
                    
                    // Update labels, truncate float to two decimal points
                    self.pressureLabel.text = String(format: "Pressure: %.02f", pressure)
                    //print(pressure)
                }
            })
            
        } else {
            let alertView = UIAlertView(title: "Error", message: "Barometer not available on this device.", delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
        }
        
    }
    
    /**************************************** Method for Dropbox ***************************************/
    
    
    // If not already signed in, sign in to dropbox, otherwise sign out.
    @IBAction func signInDropbox(_ sender: UIButton) {
        if (DropboxClientsManager.authorizedClient == nil) {
            DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self, openURL: {(url: URL) -> Void in UIApplication.shared.openURL(url)
            })
            
        } else {
            print("Logging out.")
            sender.setTitle("Sign in", for: .normal)
            signedInStatusLabel.isHidden = false
            DropboxClientsManager.unlinkClients()
        }
    }
    
    // Notification from AppDelegate that the user successfully signed in
    func handleDidLinkNotification(){
        print("Logging in.")
        dropboxSignInButton.setTitle("Sign out", for: .normal)
        signedInStatusLabel.isHidden = true
    }
    
    // Upload the given jpg image to Dropbox
    func uploadImage(jpgData: Data?){
        let client = DropboxClientsManager.authorizedClient
        if let fileData = jpgData {
            let _ = client?.files.upload(path: "/Yue_Programming/appImages/result.jpg", mode: .overwrite, input: fileData)
                .response{
                    response, error in
                    if let response = response {
                        print(response)
                    } else if let error = error {
                        // Create a popup message to signal user that upload failed.
                        let alertController = UIAlertController(title: "Error", message: "Upload failed, please check your internet connection.", preferredStyle: UIAlertControllerStyle.alert)
                        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { (result: UIAlertAction) -> Void in })
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                        print("Got a mudda Error:\(error)")
                    }
                }
                .progress{progressData in
                    print(progressData)
                    
            }
            
        } else {
            print("Error! Invalid image data!")
        }
    }
    
    
    /********************** Msc Functions ********************/
    
    //Calls this function when the tap is recognized.
    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
}

