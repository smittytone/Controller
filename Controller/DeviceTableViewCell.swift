
//  DeviceTableViewController.swift
//  Created by Tony Smith on 1/16/18.
//
//  Copyright 2018-19 Tony Smith
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


import UIKit

class DeviceTableViewCell: UITableViewCell {

    @IBOutlet weak var installSwitch: UISwitch!
    @IBOutlet weak var appName: UILabel!
    @IBOutlet weak var appCode: UILabel!
    @IBOutlet weak var appIcon: UIImageView!
    
    var rowIndex: Int = -1


    override func awakeFromNib() {
        
        super.awakeFromNib()
        
        // Set the action of the UITableViewCell's switch
        self.installSwitch.addTarget(self,
                                     action: #selector(self.flipSwitch),
                                     for: UIControl.Event.touchUpInside)
    }

    
    @objc func flipSwitch() {
        
        // The user wants to install or un-install the device from the watch

        // Package up the cell's row number and the state of the switch...
        var data: [String : Int] = [:]
        data["row"] = self.rowIndex
        data["state"] = self.installSwitch.isOn ? 1 : 0
        
        // ...and send it to the main view controller
        let nc: NotificationCenter = NotificationCenter.default
        nc.post(name: NSNotification.Name.init("com.bps.controller.install.switch.hit"),
                object: self,
                userInfo: data)
    }

}
