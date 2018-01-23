
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


class BigClockInterfaceController: WKInterfaceController, URLSessionDataDelegate {

    @IBOutlet weak var deviceLabel: WKInterfaceLabel!
    @IBOutlet weak var statusLabel: WKInterfaceLabel!
    @IBOutlet weak var lightSwitch: WKInterfaceSwitch!
    
    let deviceBasePath: String = "https://agent.electricimp.com/"
    let dots: String = "................"
    
    var aDevice: Device? = nil
    var serverSession: URLSession?
    var connexions: [Connexion] = []
    var initialQueryFlag: Bool = false
    var isConnected: Bool = false
    var loadingTimer: Timer!
    var loadCount:Int = 3

    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        self.aDevice = context as? Device
        self.deviceLabel.setText(aDevice!.name)
        self.lightSwitch.setHidden(true)
    }
    
    override func didAppear() {
        
        super.didAppear()
        
        // Get the device's current status
        self.initialQueryFlag = true
        makeConnection(nil)
        self.loadingTimer = Timer.scheduledTimer(timeInterval: 1.0,
                                                 target: self,
                                                 selector: #selector(dotter),
                                                 userInfo: nil,
                                                 repeats: true)
    }
    
    @objc func dotter() {
        
        self.loadCount = self.loadCount + 1
        if self.loadCount > 12 { self.loadCount = 0 }
        statusLabel.setText("Loading" + self.dots.suffix(self.loadCount))
    }

    
    // MARK: - Action Functions
    
    @IBAction func doSwitch(value: Bool) {

        if !isConnected { return }
        var dict = [String: String]()
        dict["setlight"] = value ? "1" : "0"
        self.lightSwitch.setTitle(value ? "On" : "Off")
        makeConnection(dict)
    }

    @IBAction func back(_ sender: Any) {

        // Go back to the device list
        popToRootController()
    }
    
    
    // MARK: - Connection Functions
    
    func makeConnection(_ data:[String:String]?) {
        
        let urlPath :String = deviceBasePath + aDevice!.code + "/settings"
        let url:URL? = URL(string: urlPath)
        
        if url == nil {
            reportError("BigClockInterfaceController.makeConnecion() passed malformed URL string + \(urlPath)")
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
                reportError("BigClockInterfaceController.makeConnection() passed malformed data")
                return
            }
        }
        
        let aConnexion = Connexion()
        aConnexion.errorCode = -1;
        aConnexion.data = NSMutableData.init(capacity:0)
        aConnexion.task = serverSession!.dataTask(with:request)
        
        if let task = aConnexion.task {
            task.resume()
            self.connexions.append(aConnexion)
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
            // Save the clock state data if the connection succeeds
            for i in 0..<self.connexions.count {
                let aConnexion = self.connexions[i]
                
                if aConnexion.task == task {
                    if let data = aConnexion.data {
                        let inString = String(data:data as Data, encoding:String.Encoding.ascii)!
                        
                        if inString != "OK" && inString != "Not Found\n" && inString != "No handler" {
                            if self.initialQueryFlag == true {
                                let dataArray = inString.components(separatedBy:".")
                                let dis = dataArray[8] as String
                                self.deviceLabel.setText(dis == "d" ? aDevice!.name + " ⛔️" : aDevice!.name)
                                self.isConnected = dis == "d" ? false : true
                                
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
                                
                                let powerString = dataArray[7] as String
                                
                                // Set the clock switch state
                                if let value = Int(powerString) {
                                    if value == 1 {
                                        lightSwitch.setOn(true)
                                        lightSwitch.setTitle("On")
                                    } else {
                                        lightSwitch.setOn(false)
                                        lightSwitch.setTitle("Off")
                                    }
                                }
                                
                                self.lightSwitch.setHidden(false)
                                self.initialQueryFlag = false
                                self.statusLabel.setHidden(true)
                                self.loadingTimer.invalidate()
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
        
        print(message)
    }

}