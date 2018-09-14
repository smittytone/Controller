
//  BigClockInterfaceController.swift
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


class ClockInterfaceController: WKInterfaceController, URLSessionDataDelegate {

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

    // MARK: App-specific outlets
    @IBOutlet weak var lightSwitch: WKInterfaceSwitch!
    @IBOutlet weak var modeSwitch: WKInterfaceSwitch!
    @IBOutlet weak var brightnessSlider: WKInterfaceSlider!
    @IBOutlet weak var worldButton: WKInterfaceButton!
    @IBOutlet weak var resetButton: WKInterfaceButton!

    // MARK: App-specific properties
    var isWorld: Bool = false
    
    // MARK: App-specific constants
    let APP_NAME: String = "ClockInterfaceController"
    enum Actions {
        // These are codes for possible actions. They are used to check whether,
        // after the action has been performed, that follow-on actions are required
        static let Other = 0
        static let GetSettings = 1
        static let Reset = 2
        static let SwitchWorld = 3
        static let SetLight = 4
    }


    // MARK: - Generic Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        self.setTitle("Devices")
        self.aDevice = context as? Device

        // Show the name of the device
        self.deviceLabel.setText(aDevice!.name)

        // Disable the controls at the outset
        controlDisabler()
    }
    
    override func didAppear() {

        // This is the 'we're about to go live' delegate function, being called
        // after 'awake()' and whenever the app is about to appear on screen, including
        // when it appears in the dock list

        // The following call does nothing, but is included in case that changes in the future
        super.didAppear()

        // Disable the app-specific buttons - we will re-enable when we're
        // sure that we're connected to the target device's agent
        controlDisabler()

        // Load and set the 'device offline' indicator
        if let image = UIImage.init(named: "offline") {
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

    override func willDisappear() {

        // The app is about to go off the screen

        // The following call does nothing, but is included in case that changes in the future
        super.willDisappear()

        // Reset the app for next time
        self.isConnected = false
        if self.loadingTimer.isValid { self.loadingTimer.invalidate() }

        // Close down and remove any existing connections
        if self.connexions.count > 0 {
            for aConnexion in self.connexions {
                aConnexion.task?.cancel()
            }

            self.connexions.removeAll()
        }
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
        self.lightSwitch.setEnabled(false)
        self.modeSwitch.setEnabled(false)
        self.brightnessSlider.setEnabled(false)
        self.worldButton.setEnabled(false)
        self.resetButton.setEnabled(false)
    }


    // MARK: - Generic Action Functions

    @IBAction func back(_ sender: Any) {

        // Go back to the device list
        popToRootController()
    }


    // MARK: - App-specific Action Functions
    
    @IBAction func doSwitch(value: Bool) {

        // Switch the display on or off
        self.lightSwitch.setTitle(value ? "On" : "Off")

        var dict = [String: String]()
        dict["on"] = value ? "true" : "false"
        let _ = makeConnection(dict, "/settings")
    }

    @IBAction func setMode(value: Bool) {
        
        // Switch the display between 24 and 12 hour mode
        self.modeSwitch.setTitle(value ? "Mode: 24" : "Mode: 12")

        var dict = [String: String]()
        dict["mode"] = value ? "true" : "false"
        let _ = makeConnection(dict, "/settings")

    }
    
    @IBAction func setBrightness(value: Float) {
        
        // Send the brightness slider value to the servrer
        var dict = [String: String]()
        dict["bright"] = "\(Int(value))"
        let _ = makeConnection(dict, "/settings")
    }

    @IBAction func setWorld(_ sender: Any) {

        // Switch between local and world time
        self.isWorld = !self.isWorld
        self.worldButton.setTitle((self.isWorld ? "Hide" : "Show") + " World Time")

        var dict = [String: String]()
        dict["action"] = "world"
        let _ = makeConnection(dict, "/action", Actions.SwitchWorld)
    }
    
    @IBAction func resetClock(_ sender: Any) {

        // Send the device-reset signal to the server
        var dict = [String: String]()
        dict["action"] = "reset"

        // NOTE Provide an action code (cf. above calls) so we can trap it
        //      at the other end and trigger a secondary action
        let _ = makeConnection(dict, "/action", Actions.Reset)
    }


    // MARK: - Generic Connection Functions

    func makeConnection(_ data:[String:String]?, _ path:String?, _ code:Int = Actions.Other) -> Bool {

        // Establish a connection to the device's agent
        // PARAMETERS
        //    data - A string:string dictionary containg the JSON data for the endpoint
        //    path - The endpoint minus the base path. If path is nil, get the state path
        //    code - Optional code indicating the action being performed. Default: 0
        // RETURNS
        //    Bool - Was the operation successful?

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

        request.addValue("Controller/" + APP_NAME, forHTTPHeaderField: "User-agent")
        
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
    

    // MARK: - URLSession Delegate Functions

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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // All the data has been supplied by the server in response to a connection -
        // or an error has been encountered
        // Parse the data and, according to the connection activity
        if error != nil {
            // React to a passed client-side error - most likely a timeout or inability to resolve the URL
            // Notify the host app
            reportError(self.APP_NAME + " could not connect to the impCloud")
            
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
            
            if index != -1 {
                self.connexions.remove(at:index)
            }

            // Clear the 'flash indicator' timer if it's running
            if self.loadingTimer.isValid {
                self.loadingTimer.invalidate()
            }
        } else {
            // Save the clock state data if the connection succeeds
            for i in 0..<self.connexions.count {
                let aConnexion = self.connexions[i]
                if aConnexion.task == task {
                    // End the connection
                    task.cancel()

                    // Check for an action code, which indicates how we proceed - do we
                    // need perform any special actions from this point?
                    if aConnexion.actionCode == Actions.Reset {
                        // Clock has just been reset, so we should re-aquire UI state data
                        // Disable the controls
                        controlDisabler()

                        // Get the new settings
                        let _ = makeConnection(nil, nil, Actions.GetSettings)
                    }

                    if aConnexion.actionCode == Actions.SwitchWorld {
                        // Update the UI based on the response to switching between local and world time
                        let object: [String:Any] = getJson(aConnexion.data)
                        if object["error"] != nil {
                            reportError(object["error"] as! String)
                        } else if let o: [String: Any] = object["world"] as? [String:Any] {
                            if let s: Bool = o["utc"] as? Bool {
                                self.isWorld = s
                                self.worldButton.setTitle((s ? "Hide" : "Show") + " World Time")
                            }
                        }
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

                            // Set the world time button
                            if let o: [String:Any] = object["world"] as? [String:Any] {
                                if let u: Bool = o["utc"] as? Bool {
                                    self.isWorld = u
                                    self.worldButton.setTitle((u ? "Hide" : "Show") + " World Time")
                                }
                            }


                            // Enable (or disable, if disconnected) the UI state
                            self.lightSwitch.setEnabled(self.isConnected)
                            self.modeSwitch.setEnabled(self.isConnected)
                            self.brightnessSlider.setEnabled(self.isConnected)
                            self.worldButton.setEnabled(self.isConnected)
                            self.resetButton.setEnabled(self.isConnected)

                            // Clear up the UI
                            self.stateImage.setHidden(false)
                            self.flashState = false
                        }
                    }

                    // Remove the processed connection from the list
                    self.connexions.remove(at:i)
                    break
                }
            }
        }
    }
    
    func reportError(_ message:String) {
        
        // Generic string logger
        print(message)
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

}
