
//  DeviceList.swift
//  Created by Tony Smith on 06/12/2016.
//
//  Copyright 2016-18 Tony Smith
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


import Foundation

class DeviceList: NSObject, NSCoding {

    static let sharedDevices: DeviceList = DeviceList()

    var devices: [Device] = []
    var currentDevice: Int = -1

    
    // MARK: - Initialization Methods

    override init() {

        self.currentDevice = -1
        self.devices = []
    }

    
    // MARK: - NSCoding Methods

    func encode(with encoder:NSCoder) {

        encoder.encode(self.currentDevice, forKey: "controller.current.index")
        encoder.encode(self.devices, forKey: "controller.device.list")
    }

    required init?(coder decoder: NSCoder) {

        self.devices = decoder.decodeObject(forKey: "controller.device.list") as! Array
        self.currentDevice = decoder.decodeInteger(forKey: "controller.current.index")
    }
}
