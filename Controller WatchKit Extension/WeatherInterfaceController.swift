
//  WeatherInterfaceController.swift
//  Created by Tony Smith on 1/17/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import WatchKit


class WeatherInterfaceController: WKInterfaceController, URLSessionDelegate {

    @IBOutlet weak var deviceLabel: WKInterfaceLabel!

    let agentBasePath: String = "https://agent.electricimp.com/"
    var receivedData: NSMutableData! = nil
    var serverSession: URLSession?
    var device: Device! = nil


    // MARK: - Lifecycle Functions

    override func awake(withContext context: Any?) {

        super.awake(withContext: context)

        device = context as! Device
        deviceLabel.setText(device.name)
    }

    override func willActivate() {

        super.willActivate()
    }

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

        let urlPath :String = self.agentBasePath + device.code + "/update"
        let url:URL? = URL(string: urlPath)

        if url == nil {
            // reportError("TimeViewController.makeConnection() passed malformed URL string + \(urlPath)")
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
                //reportError("TimeViewController.makeConnection() passed malformed data")
                return
            }
        }

        let task:URLSessionDataTask = serverSession!.dataTask(with:request)
        task.resume()
    }

    // MARK: - URLSession Delegate Functions

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

        if self.receivedData == nil { self.receivedData = NSMutableData() }
        self.receivedData.append(data)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        let rps = response as! HTTPURLResponse
        let code = rps.statusCode;

        if code > 399 {
            if code == 404 {
                completionHandler(code == 404 ? URLSession.ResponseDisposition.cancel : URLSession.ResponseDisposition.allow)
            }
        } else {
            completionHandler(URLSession.ResponseDisposition.allow);
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        if error != nil {
            //reportError("DeviceDetailViewController.didCompleteWithError() could not connect to the impCloud", "Could not connect to the Electric Imp impCloud")
        } else {
            // NOP — 
        }

        task.cancel()
        self.receivedData = nil
    }
}
