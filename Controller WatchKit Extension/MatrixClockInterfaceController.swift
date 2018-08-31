
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
    var initialQueryFlag: Bool = false
    var isConnected: Bool = false
    var flashState: Bool = false
    var loadingTimer: Timer!

    // MARK: App-specific outlets
    @IBOutlet weak var lightSwitch: WKInterfaceSwitch!
    @IBOutlet weak var modeSwitch: WKInterfaceSwitch!
    @IBOutlet weak var resetButton: WKInterfaceButton!
    @IBOutlet weak var brightnessSlider: WKInterfaceSlider!

    // MARK: App-specific constants
    let APP_NAME: String = "MatrixClockInterfaceController"
    let ACTION_CODE_RESET = 1


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
    
    override func didAppear() {
        
        super.didAppear()

        // Disable the app-specific buttons - we will re-enable when we're
        // connected to the target device's agent
        controlDisabler()

        // Load and set the 'device offline' indicator
        if let image = UIImage.init(named: "offline") {
            self.stateImage.setImage(image)
        }

        // Get the device's current status
        self.initialQueryFlag = true
        let success = makeConnection(nil, nil)
        if success {
            self.loadingTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                                     target: self,
                                                     selector: #selector(dotter),
                                                     userInfo: nil,
                                                     repeats: true)
        }
    }
    
    @objc func dotter() {
        
        // Flash the indictor by alternately showing and hiding it
        self.stateImage.setHidden(self.flashState)
        self.flashState = !self.flashState
    }

    func controlDisabler() {

        self.lightSwitch.setEnabled(false)
        self.modeSwitch.setEnabled(false)
        self.brightnessSlider.setEnabled(false)
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
        var dict = [String: String]()
        dict["setlight"] = value ? "1" : "0"
        self.lightSwitch.setTitle(value ? "On" : "Off")
        let _ = makeConnection(dict, nil)
    }
    
    @IBAction func setMode(value: Bool) {
        
        // Switch the display between 24 and 12 hour mode
        var dict = [String: String]()
        dict["setmode"] = value ? "1" : "0"
        self.modeSwitch.setTitle(value ? "Mode: 24" : "Mode: 12")
        let _ = makeConnection(dict, nil)
    }

    @IBAction func setBrightness(value: Float) {
        
        // Set the display brightness
        var dict = [String: String]()
        dict["setbright"] = "\(Int(value))"
        let _ = makeConnection(dict, nil)
    }

    @IBAction func resetClock(_ sender: Any) {

        // Send the reset signal
        var dict = [String: String]()
        dict["action"] = "reset"
        let _ = makeConnection(dict, "/action", self.ACTION_CODE_RESET)
    }

    
    // MARK: - Generic Connection Functions

    func makeConnection(_ data:[String:String]?, _ path:String?, _ code:Int = 0) -> Bool {

        // Establish a connection to the device's agent
        // PARAMETERS
        //    data - A string:string dictionary containg the JSON data for the endpoint
        //    path - The endpoint minus the base path. If path is nil, get the state path
        //    code - Optional code indicating the action being performed. Default: 0
        // RETURNS
        //    Bool - was the operation successful

        let urlPath :String = deviceBasePath + aDevice!.code + (path != nil ? path! : "/settings")
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
            reportError("Could not connect to the impCloud")
            
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
                    if aConnexion.actionCode == self.ACTION_CODE_RESET {

                        // Clock has just been reset, so we should re-aquire UI state data
                        self.initialQueryFlag = true
                        controlDisabler()
                        let _ = makeConnection(nil, nil)
                    }

                    if let data = aConnexion.data {
                        let inputString = String(data:data as Data, encoding:String.Encoding.ascii)!
                        if inputString != "OK" && inputString != "Not Found\n" && inputString != "No handler" {
                            if self.initialQueryFlag == true {
                                self.loadingTimer.invalidate()
                                let dataArray = inputString.components(separatedBy:".")
                                
                                // Incoming string looks like this:
                                //    1.1.1.1.01.1.01.1.d.1
                                //
                                // with the values:
                                //    0. mode (1: 24hr, 0: 12hr)
                                //    1. bst state
                                //    2. colon flash
                                //    3. colon state
                                //    4. brightness
                                //    5. world time state
                                //    6. world time offset (0-24 -> -12 to 12)
                                //    7. display state
                                //    8. connection status
                                //    9. debug status
                                
                                let state = dataArray[8] as String
                                self.isConnected = (state == "d" ? false : true)
                                
                                // Set the clock display switch state
                                let powerState = dataArray[7] as String
                                if let value = Int(powerState) {
                                    if value == 1 {
                                        self.lightSwitch.setOn(true)
                                        self.lightSwitch.setTitle("On")
                                    } else {
                                        self.lightSwitch.setOn(false)
                                        self.lightSwitch.setTitle("Off")
                                    }
                                }

                                // Set the clock mode switch state
                                let modeState = dataArray[0] as String
                                if let value = Int(modeState) {
                                    if value == 1 {
                                        self.modeSwitch.setOn(true)
                                        self.modeSwitch.setTitle("Mode: 24")
                                    } else {
                                        self.modeSwitch.setOn(false)
                                        self.modeSwitch.setTitle("Mode: 12")
                                    }
                                }

                                // Set the clock brightness slider state
                                let brightnessState = dataArray[4] as String
                                if let value = Int(brightnessState) {
                                    self.brightnessSlider.setValue(Float(value))
                                }

                                // Set the online/offline indicator
                                let nameString = self.isConnected ? "online" : "offline"
                                if let image = UIImage.init(named: nameString) {
                                    self.stateImage.setImage(image)
                                }

                                // Enable or disable app-specific controls according to connection state
                                self.lightSwitch.setEnabled(self.isConnected)
                                self.modeSwitch.setEnabled(self.isConnected)
                                self.brightnessSlider.setEnabled(self.isConnected)
                                self.resetButton.setEnabled(self.isConnected)

                                self.stateImage.setHidden(false)
                                self.initialQueryFlag = false
                                self.flashState = false
                            }
                        }
                    }
                    
                    // End connection
                    task.cancel()
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

}
