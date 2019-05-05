
//  MatrixClockInterfaceController.swift
//  Created by Tony Smith on 1/17/18.
//
//  Copyright 2018 Tony Smith
//
//  SPDX-License-Identifier: MIT
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
//  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.


import WatchKit


class MatrixClockInterfaceController: WKInterfaceController, URLSessionDataDelegate {

    // MARK: Generic outlets
    @IBOutlet weak var deviceLabel: WKInterfaceLabel!
    @IBOutlet weak var stateImage: WKInterfaceImage!

    // MARK: Generic properties
    let deviceBasePath: String = "https://agent.electricimp.com/"
    var aDevice: Device? = nil
    var serverSession: URLSession?
    var connexions: [Connexion] = []
    var isConnected: Bool = false
    var flashState: Bool = false
    var loadingTimer: Timer!
    var timeStamp: Date! = Date.init(timeIntervalSince1970: 0)
    
    // MARK: App-specific outlets
    @IBOutlet weak var lightSwitch: WKInterfaceSwitch!
    @IBOutlet weak var modeSwitch: WKInterfaceSwitch!
    @IBOutlet weak var resetButton: WKInterfaceButton!
    @IBOutlet weak var brightnessSlider: WKInterfaceSlider!

    // MARK: App-specific constants
    let APP_NAME: String = "MatrixClockInterfaceController"
    let REFRESH_INTERVAL: Double = 120.0

    enum Actions {
        // These are codes for possible actions. They are used to check whether,
        // after the action has been performed, that follow-on actions are required
        static let Other = 0
        static let GetSettings = 1
        static let Reset = 2
    }


    // MARK: - Generic Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)
        
        self.setTitle("Devices")
        self.aDevice = context as? Device

        // Show the device name and set the controller title
        self.deviceLabel.setText(aDevice!.name)

        // Set control defaults
        self.lightSwitch.setTitle("On")
        self.modeSwitch.setTitle("Mode: 24")
        self.brightnessSlider.setValue(15)

        // Disable controls from the start
        controlDisabler()
    }
    
    override func willActivate() {

        // The following call does nothing, but is included in case that changes in the future
        super.willActivate()

        let now: Date = Date()
        var flag: Bool = false

        // Set flag if we're activating more than REFRESH_INTERVAL seconds
        // since we last deactivated
        if now.compare(self.timeStamp + REFRESH_INTERVAL) == ComparisonResult.orderedDescending {
            flag = true
        }

        if !self.isConnected || flag {
            // We're not connected or it's more that REFRESH_INTERVAL seconds since we deactivated

            // Disable the app-specific buttons - we will re-enable when we're
            // sure that we're connected to the target device's agent
            controlDisabler()

            // Load and set the 'device offline' indicator
            if let image = UIImage.init(named: "connecting") {
                self.stateImage.setImage(image)
            }

            // Get the device's current status
            let success = makeConnection(nil, nil, Actions.GetSettings)
            if success {
                self.loadingTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                                         target: self,
                                                         selector: #selector(dotter),
                                                         userInfo: nil,
                                                         repeats: true)
            }
        }
    }

    override func didAppear() {
        
        // This is the 'we're about to go live' delegate function, being called
        // after 'awake()' and whenever the app is about to appear on screen, including
        // when it appears in the dock list

        // The following call does nothing, but is included in case that changes in the future
        super.didAppear()
    }

    override func willDisappear() {

        // This is called when the user goes back to the main menu

        // The following call does nothing, but is included in case that changes in the future
        super.willDisappear()

        // Mark us as disconnected — 'didDeactivate()' will have done the rest
        self.isConnected = false
    }

    override func didDeactivate() {

        // This is called when the user goes back to the main menu, hits the crown, or the screen sleeps

        // The following call does nothing, but is included in case that changes in the future
        super.didDeactivate()

        // Store time
        self.timeStamp = Date()

        // Clear any activities we don't want going in the background
        resetApp()
    }

    @objc func dotter() {
        
        // Flash the indictor by alternately showing and hiding it
        self.stateImage.setHidden(self.flashState)
        self.flashState = !self.flashState
    }

    func controlDisabler() {

        // Disable all of the visible controls.
        // Typically performed right before checking whether the device is online
        // (in which case, they can be enabled - see didCompleteWithError()

        // Force the disabled switches' tint colour to grey, as this does not
        // happen automatically when the switches are disabled
        self.lightSwitch.setColor(UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))
        self.modeSwitch.setColor(UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))

        // Disable the controls
        self.lightSwitch.setEnabled(false)
        self.modeSwitch.setEnabled(false)
        self.brightnessSlider.setEnabled(false)
        self.resetButton.setEnabled(false)
    }

    func resetApp() {

        // Clear the timer, if it's running
        if self.loadingTimer.isValid {
            self.loadingTimer.invalidate()
        }

        // Close down and remove any existing connections
        if self.connexions.count > 0 {
            for aConnexion in self.connexions {
                aConnexion.task?.cancel()
            }

            self.connexions.removeAll()
        }
    }

    
    // MARK: - Generic Action Functions

    @IBAction func back(_ sender: Any) {

        // Go back to the device list
        popToRootController()
    }


    // MARK: - App-specific Action Functions
    
    @IBAction func doSwitch(value: Bool) {

        // Switch the display on or off by sending a bool value in JSON
        // eg. { "setlight" : false }
        var dict = [String: Any]()
        dict["setlight"] = value
        self.lightSwitch.setTitle(value ? "On" : "Off")
        let _ = makeConnection(dict, "/settings")
    }
    
    @IBAction func setMode(value: Bool) {
        
        // Switch the display between 24 and 12 hour mode by sending a bool value in JSON
        // where true = 24-hour, false = 12-hour
        // eg. { "setmode" : true }
        var dict = [String: Any]()
        dict["setmode"] = value
        self.modeSwitch.setTitle(value ? "Mode: 24" : "Mode: 12")
        let _ = makeConnection(dict, "/settings")
    }

    @IBAction func setBrightness(value: Float) {
        
        // Set the display brightness by sending a string value in JSON
        // eg. { "setbrigt" : "15" }
        var dict = [String: Any]()
        dict["setbright"] = "\(Int(value))"
        let _ = makeConnection(dict, "/settings")
    }

    @IBAction func resetClock(_ sender: Any) {

        // Send the reset signal by sending a string action type in JSON
        // ie. { "action" : "reset" }
        var dict = [String: Any]()
        dict["action"] = "reset"
        let _ = makeConnection(dict, "/action", Actions.Reset)
    }

    
    // MARK: - Generic Connection Functions

    func makeConnection(_ data:[String:Any]?, _ path:String?, _ code:Int = Actions.Other) -> Bool {

        // Establish a connection to the device's agent
        // PARAMETERS
        //    data - A string:string dictionary containg the JSON data for the endpoint
        //    path - The endpoint minus the base path. If path is nil, get the state path
        //    code - Optional code indicating the action being performed. Default: 0
        // RETURNS
        //    Bool - was the operation successful

        let urlPath :String = deviceBasePath + aDevice!.code + (path != nil ? path! : "/controller/state")
        let url:URL? = URL(string: urlPath)
        
        if url == nil {
            reportError(APP_NAME + ".makeConnecion() passed malformed URL string + \(urlPath)")
            return false
        }
        
        if self.serverSession == nil {
            self.serverSession = URLSession(configuration:URLSessionConfiguration.default,
                                            delegate:self,
                                            delegateQueue:OperationQueue.main)
        }
        
        var request = URLRequest(url: url!,
                                 cachePolicy:URLRequest.CachePolicy.reloadIgnoringLocalCacheData,
                                 timeoutInterval: 60.0)
        
        if (data != nil) {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: data!, options: [])
                request.httpMethod = "POST"
            } catch {
                reportError(APP_NAME + ".makeConnection() passed malformed data")
                return false
            }
        }
        
        let aConnexion = Connexion()
        aConnexion.errorCode = -1
        aConnexion.actionCode = code
        aConnexion.data = NSMutableData.init(capacity:0)
        aConnexion.task = serverSession!.dataTask(with:request)
        
        if let task = aConnexion.task {
            task.resume()
            self.connexions.append(aConnexion)
        } else {
            reportError(self.APP_NAME + ".makeConnection() couldn't create a SessionTask")
            return false
        }

        return true
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // This delegate method is called when the server sends some data back
        // Add the data to the correct connexion object
        for aConnexion in self.connexions {
            // Run through the connections in our list and add the incoming data to the correct one
            if aConnexion.task == dataTask {
                if let connData = aConnexion.data {
                    connData.append(data)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        // This delegate method is called when the server responds to the connection request
        // Use it to trap certain status codes
        let rps = response as! HTTPURLResponse
        let code = rps.statusCode;
        
        if code > 399 {
            // The API has responded with a status code that indicates an error
            
            for aConnexion in self.connexions {
                // Run through the connections in our list and
                // add the incoming error code to the correct one
                if aConnexion.task == dataTask { aConnexion.errorCode = code }
                
                if code == 404 {
                    // Agent is moving for production shift, so delay check
                    completionHandler(URLSession.ResponseDisposition.cancel)
                } else {
                    completionHandler(URLSession.ResponseDisposition.allow)
                }
            }
        } else {
            completionHandler(URLSession.ResponseDisposition.allow);
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // All the data has been supplied by the server in response to a connection -
        // or an error has been encountered
        // Parse the data and, according to the connection activity
        if error != nil {
            // React to a passed client-side error - most likely a timeout or inability to resolve the URL
            // Notify the host app
            reportError(self.APP_NAME + " could not connect to the impCloud (" + error!.localizedDescription + ")")
            
            // Terminate the failed connection and remove it from the list of current connections
            var index = -1
            
            for i in 0..<self.connexions.count {
                // Run through the connections in the list and find the one that has just finished loading
                let aConnexion = self.connexions[i]
                
                if aConnexion.task == task {
                    task.cancel()
                    index = i
                }
            }
            
            if index != -1 { self.connexions.remove(at:index) }

            // Clear the 'flash indicator' timer if it's running
            if self.loadingTimer.isValid { self.loadingTimer.invalidate() }
        } else {
            // Save the clock state data if the connection succeeds
            for i in 0..<self.connexions.count {
                let aConnexion = self.connexions[i]
                if aConnexion.task == task {

                    // End the connection
                    task.cancel()

                    if aConnexion.actionCode == Actions.Reset {
                        // Clock has just been reset, so we should re-aquire UI state data
                        controlDisabler()
                        let _ = makeConnection(nil, nil, Actions.GetSettings)
                    }

                    if aConnexion.actionCode == Actions.GetSettings {
                        // We have got the current settings from the server, so we can update the UI
                        self.loadingTimer.invalidate()

                        let object: [String:Any] = getJson(aConnexion.data)
                        if object["error"] != nil {
                            reportError(object["error"] as! String)
                        } else {
                            if let s: Bool = object["isconnected"] as? Bool {
                                self.isConnected = s
                            }

                            // Set the online/offline indicator
                            let nameString = self.isConnected ? "online" : "offline"
                            if let image = UIImage.init(named: nameString) {
                                self.stateImage.setImage(image)
                            }

                            // Set the display on/off switch
                            if let s: Bool = object["on"] as? Bool {
                                self.lightSwitch.setTitle(s ? "On" : "Off")
                                self.lightSwitch.setOn(s)
                            }

                            // Set the clock mode switch
                            if let s: Bool = object["mode"] as? Bool {
                                self.modeSwitch.setTitle(s ? "Mode: 24" : "Mode: 12")
                                self.modeSwitch.setOn(s)
                            }

                            // Set the clock brightness slider state
                            if let v: Float = object["bright"] as? Float {
                                self.brightnessSlider.setValue(v)
                            }

                            // Set the switches' colour
                            let color = self.isConnected ?
                                UIColor.init(red: 0.71, green: 0.0, blue: 0.02, alpha: 1.0) :
                                UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
                            self.lightSwitch.setColor(color)
                            self.modeSwitch.setColor(color)

                            // Enable or disable app-specific controls according to connection state
                            self.lightSwitch.setEnabled(self.isConnected)
                            self.modeSwitch.setEnabled(self.isConnected)
                            self.brightnessSlider.setEnabled(self.isConnected)
                            self.resetButton.setEnabled(self.isConnected)

                            self.stateImage.setHidden(false)
                            self.flashState = false
                        }
                    }

                    self.connexions.remove(at:i)
                    break
                }
            }
        }
    }
    
    func getJson(_ data:NSMutableData?) -> [String: Any] {

        // Interpret the received data as JSON and convert to a Dictionary
        if let soliddata = data {
            //let inputString = String(data:soliddata as Data, encoding:String.Encoding.ascii)!
            //print(inputString)
            do {
                let json = try JSONSerialization.jsonObject(with: soliddata as Data, options: [])
                if let object: [String: Any] = json as? [String: Any] {
                    return object
                }
            } catch {
                return ["error":"Settings JSON is invalid"]
            }
        }

        return ["error":"Data error"]
    }

    func reportError(_ message:String) {
        
        // Generic string logger
        print(message)
    }

}
