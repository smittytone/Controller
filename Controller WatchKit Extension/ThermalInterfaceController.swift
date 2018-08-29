
//  ThermalInterfaceController.swift
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


class ThermalInterfaceController: WKInterfaceController, URLSessionDataDelegate {

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
    @IBOutlet weak var resetButton: WKInterfaceButton!
    @IBOutlet weak var lightSwitch: WKInterfaceSwitch!

    // MARK: App-specific properties
    let appName: String = "ThermalInterfaceController"


    // MARK: - Generic Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        self.setTitle("Devices")
        self.aDevice = context as? Device

        // Show the name of the device
        self.deviceLabel.setText(aDevice!.name)

        // Disable the app-specific buttons - we will re-enable when we're
        // connected to the target device's agent
        self.resetButton.setEnabled(false)
        self.lightSwitch.setEnabled(false)

        // Load and set the 'device offline' indicator
        if let image = UIImage.init(named: "offline") {
            self.stateImage.setImage(image)
        }
    }

    override func didAppear() {
        
        super.didAppear()
        
        // Get the device's current status
        self.initialQueryFlag = true
        makeConnection(nil, nil)
        self.loadingTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                                 target: self,
                                                 selector: #selector(dotter),
                                                 userInfo: nil,
                                                 repeats: true)
    }
    
    @objc func dotter() {
        
        // Flash the indictor by alternately showing and hiding it
        self.stateImage.setHidden(self.flashState)
        self.flashState = !self.flashState
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
        dict["action"] = "power"
        dict["power"] = value ? "1" : "0"
        self.lightSwitch.setTitle(value ? "On" : "Off")
        makeConnection(dict, "/actions")
    }
    
    @IBAction func reboot(_ sender: Any) {

        // Send the restart signal
        // NOTE This triggers a forecast update
        if !isConnected { return }
        var dict = [String: String]()
        dict["action"] = "reboot"
        makeConnection(dict, "/actions")
    }


    // MARK: - Generic Connection Functions

    func makeConnection(_ data:[String:String]?, _ path:String?, _ code:Int = 0) {

        // Establish a connection to the device's agent
        // PARAMETERS
        //    data - A string:string dictionary containg the JSON data for the endpoint
        //    path - The endpoint minus the base path. If path is nil, get the state path
        //    code - Optional code indicating the action being performed. Default: 0
        // RETURNS
        //    Nothing

        let urlPath :String = deviceBasePath + aDevice!.code + (path != nil ? path! : "/controller/state")
        let url:URL? = URL(string: urlPath)
        
        if url == nil {
            reportError(appName + ".makeConnecion() passed malformed URL string + \(urlPath)")
            return
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
                reportError(appName + ".makeConnection() passed malformed data")
                return
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
        }
    }


    // MARK: - URLSession Delegate Functions

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
        } else {
            for i in 0..<self.connexions.count {
                let aConnexion = self.connexions[i]
                if aConnexion.task == task {
                    if let data = aConnexion.data {
                        if self.initialQueryFlag == true {
                            self.loadingTimer.invalidate()

                            let inputString = String(data:data as Data, encoding:String.Encoding.ascii)!
                            let dataArray = inputString.components(separatedBy:".")

                            // The data string is formatted as follows:
                            // "0.1.2.3", where
                            // 0 - the LED brightness value (0-15)
                            // 1 - the LED power state (1 = on, 0 = off)
                            // 2 - the LED orientation (1 = left, 0 = right)
                            // 3 - the device online status (1 = connected, 0 = disconnected)
                            
                            self.lightSwitch.setTitle(dataArray[1] == "1" ? "On" : "Off")
                            self.isConnected = dataArray[3] == "1" ? true : false

                            // Set the online/offline indicator
                            let nameString = self.isConnected ? "online" : "offline"
                            if let image = UIImage.init(named: nameString) {
                                self.stateImage.setImage(image)
                            }

                            // Enable or disable app-specific controls according to connection state
                            self.lightSwitch.setEnabled(self.isConnected)
                            self.resetButton.setEnabled(self.isConnected)

                            self.stateImage.setHidden(false)
                            self.initialQueryFlag = false
                        }
                        
                        task.cancel()
                        self.connexions.remove(at:i)
                        break
                    }
                }
            }
        }
    }
    
    func reportError(_ message:String) {
        
        // Generic string logger
        print(message)
    }
}