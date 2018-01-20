
//  WeatherInterfaceController.swift
//  Created by Tony Smith on 1/17/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import WatchKit


class WeatherInterfaceController: WKInterfaceController, URLSessionDelegate {

    @IBOutlet weak var deviceLabel: WKInterfaceLabel!
    @IBOutlet weak var statusLabel: WKInterfaceLabel!
    
    let deviceBasePath: String = "https://agent.electricimp.com/"
    var aDevice: Device? = nil
    var serverSession: URLSession?
    var connexions: [Connexion] = []
    
    
    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        self.aDevice = context as? Device
        self.deviceLabel.setText(aDevice!.name)
    }

    override func didAppear() {
        
        super.didAppear()
        
        self.statusLabel.setHidden(true)
    }
    
    
    // MARK: - Action Functions

    @IBAction func update(_ sender: Any) {

        // Send the reset signal
        var dict = [String: String]()
        dict["action"] = "update"
        makeConnection(dict)
    }

    @IBAction func reboot(_ sender: Any) {

        // Send the reset signal
        var dict = [String: String]()
        dict["action"] = "reboot"
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
            reportError("WeatherInterfaceController.makeConnecion() passed malformed URL string + \(urlPath)")
            return
        }
        
        if serverSession == nil {
            serverSession = URLSession(configuration:URLSessionConfiguration.default,
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
                reportError("WeatherInterfaceController.makeConnection() passed malformed data")
                return
            }
        }
        
        let aConnexion = Connexion()
        aConnexion.errorCode = -1;
        aConnexion.data = NSMutableData.init(capacity:0)
        aConnexion.task = serverSession!.dataTask(with:request)
        
        if let task = aConnexion.task {
            task.resume()
            connexions.append(aConnexion)
        }
    }

    // MARK: - URLSession Delegate Functions

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

        // This delegate method is called when the server sends some data back
        // Add the data to the correct connexion object
        for aConnexion in connexions {
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
            
            for aConnexion in connexions {
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
            
            for i in 0..<connexions.count {
                // Run through the connections in the list and find the one that has just finished loading
                let aConnexion = connexions[i]
                
                if aConnexion.task == task {
                    task.cancel()
                    index = i
                }
            }
            
            if index != -1 { connexions.remove(at:index) }
        } else {
            for i in 0..<connexions.count {
                let aConnexion = connexions[i]
                
                if aConnexion.task == task {
                    task.cancel()
                    connexions.remove(at:i)
                    break
                }
            }
        }
    }
    
    func reportError(_ message:String) {
        
        print(message)
    }
}
