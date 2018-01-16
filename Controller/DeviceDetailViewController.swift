
//  DeviceDetailViewController.swift
//  Created by Tony Smith on 1/16/18.
//  Copyright © 2018 Black Pyramid. All rights reserved.


import UIKit

class DeviceDetailViewController: UIViewController,
    UITextFieldDelegate,
    URLSessionDelegate,
    URLSessionDataDelegate {

    @IBOutlet weak var codeField: UITextField!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var appTypeField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var supportLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var connectionProgress: UIActivityIndicatorView!
    
    var myDevices: DeviceList!
    var currentDevice: Device!
    var receivedData: NSMutableData! = nil
    var devSession: URLSession?

    override func viewDidLoad() {

        super.viewDidLoad()

        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        // Set up the UI
        self.errorLabel.isHidden = true
        self.appTypeField.isEnabled = false

        // Display the device info
        if self.currentDevice != nil {
            // New items have a 'code' property that is an empty string
            if currentDevice.code.count > 0 {
                self.codeField.text = self.currentDevice.code
                self.appTypeField.text = getAppTypeFromInt(self.currentDevice.app)
                self.nameField.text = self.currentDevice.name
            }
        }
    }

    override func didReceiveMemoryWarning() {

        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func appWillQuit(note:NSNotification) {

        NotificationCenter.default.removeObserver(self)
    }


    // MARK: - Control Methods

    @objc func changeDetails() {

        if self.currentDevice != nil {
            // The view is about to close so save the text fields' content
            if self.currentDevice.code != codeField.text! {
                self.currentDevice.code = codeField.text!
                self.currentDevice.changed = true
            }

            if self.currentDevice.name != nameField.text! {
                self.currentDevice.name = nameField.text!
                self.currentDevice.changed = true
            }
        }

        // Stop listening for 'will enter foreground' notifications
        NotificationCenter.default.removeObserver(self)

        // Jump back to the list of devices
        self.navigationController!.popViewController(animated: true)
    }


    // MARK: - Text Field Delegate Methods

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

        for item in self.view.subviews {
            let view = item as UIView
            if view.isKind(of: UITextField.self) { view.resignFirstResponder() }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {

        if textField == self.codeField {
            // User has entered a code, so we should get the device info
            getDeviceInfo()
        }
    }

    func getDeviceInfo() {

        if let code = self.codeField.text {
            let url:URL? = URL(string: "https://agent.electricimp.com/" + code + "/info")

            if url == nil {
                reportError("DeviceDetailViewController.getDeviceInfo() generated a malformed URL string")
                self.errorLabel.isHidden = false
                self.errorLabel.text = "Error contacting the device"
                return
            }

            connectionProgress.startAnimating()

            var request:URLRequest = URLRequest(url:url!,
                                                cachePolicy:URLRequest.CachePolicy.reloadIgnoringLocalCacheData,
                                                timeoutInterval:60.0)

            request.httpMethod = "GET"

            if self.devSession == nil {
                self.devSession = URLSession(configuration:URLSessionConfiguration.default,
                                         delegate:self,
                                         delegateQueue:OperationQueue.main)
            }

            let task:URLSessionDataTask = devSession!.dataTask(with:request)
            task.resume()
        }
    }


    // MARK: - URLSession Methods

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
            reportError("Could not connect to the Electric Imp impCloud")
            self.errorLabel.isHidden = false
            self.errorLabel.text = "Could not connect to the device"
        } else {
            if self.receivedData.length > 0 {
                let dataString:String? = String(data:self.receivedData as Data, encoding:String.Encoding.ascii)

                var appData: [String:String]

                do {
                    appData = try JSONSerialization.jsonObject(with: self.receivedData as Data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String:String]
                    let code = appData["app"]
                    self.appTypeField.text = getAppTypeAsString(code!)
                    self.currentDevice.app = getAppTypeAsInt(code!)
                    self.currentDevice.watchSupported = appData["watchsupported"] == "true" ? true : false
                    self.supportLabel.text = "Watch control" + (appData["watchsupported"] == "false" ? " not" : "") + " supported"
                    self.currentDevice.changed = true
                } catch {
                    self.errorLabel.isHidden = false
                    self.errorLabel.text = "Could not connect to the device"
                }
            }
        }

        task.cancel()
        self.connectionProgress.stopAnimating()
        self.receivedData = nil
    }

    func reportError(_ message:String) {
        NSLog(message)
    }

    func getAppTypeAsString(_ code:String) -> String {

        if code == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { return "Weather" }
        if code == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { return "HomeWeather" }
        if code == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { return "MatrixClock" }

        return "Unknown"
    }

    func getAppTypeAsInt(_ code:String) -> Int {

        if code == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { return 0 }
        if code == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { return 1 }
        if code == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { return 2 }

        return 99
    }

    func getAppTypeFromInt(_ code:Int) -> String {

        if code == 0 { return "Weather" }
        if code == 1 { return "HomeWeather" }
        if code == 2 { return "MatrixClock" }

        return "Unknown"
    }


}

