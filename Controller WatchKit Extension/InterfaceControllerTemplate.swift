
//  InterfaceControllerTemplate.swift
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


class <AppName>InterfaceController: WKInterfaceController, URLSessionDataDelegate {

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
    @IBOutlet weak var <ButtonName>: WKInterfaceButton!
    @IBOutlet weak var <SwitchName>: WKInterfaceSwitch!
    // NOTE The 'Back' button should be considered as generic to all apps

    // MARK: App-specific properties
    let appName: String = "<AppName>"
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

        // App is loaded for the first time when the user selects it from
        // the main menu
        super.awake(withContext: context)

        self.aDevice = context as? Device
        self.setTitle("Devices")

        // Show the name of the device
        self.deviceLabel.setText(aDevice!.name)

        // Disable the app-specific buttons - we will re-enable when we're
        // sure that we're connected to the target device's agent
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
    }

    override func didDeactivate() {

        // This is called when the user goes back to the main menu, hits the crown, or the screen sleeps

        // The following call does nothing, but is included in case that changes in the future
        super.didDeactivate()

        // Store the current deactivation time
        self.timeStamp = Date()

        // Clear any activities we don't want going in the background
        resetApp()
    }

    override func didAppear() {
        
        // App is appearing on the screen, either after 'awake()' was called,
        // or if the user never went back to the main menu and instead just
        // switched to another watch app. As a result, we do the main UI
        // state set-up here
        super.didAppear()
    }
    
    override func willDisappear() {

        // This is called when the user goes back to the main menu

        // The following call does nothing, but is included in case that changes in the future
        super.willDisappear()

        // Mark us as disconnected — 'didDeactivate()' will have done the rest
        self.isConnected = false
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
        self.<SwitchName>.setColor(UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))

        // Disable the app-specific buttons, etc.
        self.<ButtonName>.setEnabled(false)
        self.<SwitchName>.setEnabled(false)
    }
    
    
    // MARK: - Generic Action Functions

    @IBAction func back(_ sender: Any) {

        // Go back to the device list
        popToRootController()
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


    // MARK: - App-specific Action Functions

    @IBAction func update(_ sender: Any) {

        // Send the update forecast signal
        var dict = [String: String]()
        dict["<key>"] = "<value>"

        // Attempt to send the action
        // NOTE We don't care what the result was
        let _ = makeConnection(dict, "<endpoint>")
    }

    
    // MARK: - Generic Connection Functions

    func makeConnection(_ data:[String:String]?, _ path:String?, _ code:Int = Actions.Other) -> Bool {

        // Establish a connection to the device's agent
        // PARAMETERS
        //    data - A string:string dictionary containg the JSON data for the endpoint
        //    path - The endpoint minus the base path. If path is nil, get the state path
        //    code - Optional code indicating the action being performed. Default: 0
        // RETURNS
        //    Bool - Was the operation successful

        let urlPath :String = deviceBasePath + aDevice!.code + (path != nil ? path! : "/controller/state")
        let url:URL? = URL(string: urlPath)
        
        if url == nil {
            reportError(appName + ".makeConnecion() passed malformed URL string + \(urlPath)")
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
                reportError(appName + ".makeConnection() passed malformed data")
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
            reportError(self.appName + ".makeConnection() couldn't create a SessionTask")
            return false
        }

        return true
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
            for i in 0..<self.connexions.count {
                let aConnexion = self.connexions[i]
                if aConnexion.task == task {
                    // End the connection
                    task.cancel()
                    
                    if aConnexion.actionCode == Actions.GetSettings {
                        self.loadingTimer.invalidate()

                        // Try and convert the incoming data to JSON as a Dictionary
                        // We expect the data to be something like:
                        // { "isconnected" : true,
                        //   "switchstate" : false }
                        // The app-sent JSON should always contain the 'isconencted' key at minimum
                        let object: [String:Any] = getJson(aConnexion.data)
                        
                        if object["error"] != nil {
                            reportError(object["error"] as! String)
                        } else {
                            // Is the device connected?
                            if let s: Bool = object["isconnected"] as? Bool {
                                self.isConnected = s
                            }
                        
                            // Set the online/offline indicator
                            let nameString = self.isConnected ? "online" : "offline"
                            if let image = UIImage.init(named: nameString) {
                                self.stateImage.setImage(image)
                            }

                            // Enable or disable app-specific controls according to connection state
                            self.<ButtonName>.setEnabled(self.isConnected)
                            self.<SwitchName>.setEnabled(self.isConnected)

                            // Set the switches' colour - ie. grey if it is disabled
                            let color = self.isConnected ?
                                UIColor.init(red: 0.71, green: 0.0, blue: 0.02, alpha: 1.0) :
                                UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
                            self.<SwitchName>.setColor(color)

                            // Clear up the UI
                            self.stateImage.setHidden(false)
                            self.flashState = false
                        }

                        // Remove the processed connection from the list
                        self.connexions.remove(at:i)
                        break
                    }
                }
            }
        }
    }
    
    func getJson(_ data:NSMutableData?) -> [String: Any] {

        // Interpret the received data as JSON and convert to a Dictionary
        if let soliddata = data {
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
