
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
    var serverSession: URLSession?


    // MARK: - Lifecycle Functions

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
                self.appTypeField.text = getAppTypeAsString(self.currentDevice.app)
                self.nameField.text = self.currentDevice.name
                self.supportLabel.text = "Watch control" + (!self.currentDevice.watchSupported ? " not" : "") + " supported"
            }
        }
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


    // MARK: - Connection Functions

    func getDeviceInfo() {

        if let code = self.codeField.text {
            let url:URL? = URL(string: "https://agent.electricimp.com/" + code + "/info")

            if url == nil {
                reportError("DeviceDetailViewController.getDeviceInfo() generated a malformed URL string", "Could not connect to the device")
                return
            }

            connectionProgress.startAnimating()

            var request:URLRequest = URLRequest(url:url!,
                                                cachePolicy:URLRequest.CachePolicy.reloadIgnoringLocalCacheData,
                                                timeoutInterval:60.0)
            request.httpMethod = "GET"

            if self.serverSession == nil {
                self.serverSession = URLSession(configuration:URLSessionConfiguration.default,
                                                delegate:self,
                                                delegateQueue:OperationQueue.main)
            }

            let task:URLSessionDataTask = serverSession!.dataTask(with:request)
            task.resume()
        }
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
            reportError("DeviceDetailViewController.didCompleteWithError() could not connect to the impCloud", "Could not connect to the device")
        } else {
            if self.receivedData.length > 0 {
                // let dataString:String? = String(data:self.receivedData as Data, encoding:String.Encoding.ascii)
                var appData: [String:String]

                do {
                    appData = try JSONSerialization.jsonObject(with: self.receivedData as Data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String:String]
                    let code = appData["app"]
                    self.appTypeField.text = getAppTypeAsString(code!)
                    self.currentDevice.app = code!
                    self.currentDevice.watchSupported = appData["watchsupported"] == "true" ? true : false
                    self.supportLabel.text = "Watch control" + (appData["watchsupported"] == "false" ? " not" : "") + " supported"
                    self.currentDevice.changed = true
                } catch {
                    reportError("DeviceDetailViewController.didCompleteWithError() send malformed JSON" , "Could not connect to the device")
                }
            }
        }

        task.cancel()
        self.connectionProgress.stopAnimating()
        self.receivedData = nil
    }

    func reportError(_ logMessage:String, _ reportMessage:String) {

        // Log the detailed message
        NSLog(logMessage)

        // Report the basic message to the user via an alert
        let alert = UIAlertController.init(title: "Error", message: reportMessage, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true)
    }

    func getAppTypeAsString(_ code:String) -> String {

        if code == "761DDC8C-E7F5-40D4-87AC-9B06D91A672D" { return "Weather" }
        if code == "8B6B3A11-00B4-4304-BE27-ABD11DB1B774" { return "HomeWeather" }
        if code == "0028C36B-444A-408D-B862-F8E4C17CB6D6" { return "MatrixClock" }

        return "Unknown"
    }

}

