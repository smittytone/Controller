
//  DeviceList.swift
//  Created by Tony Smith on 06/12/2016.
//
//  Copyright 2016-19 Tony Smith
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

class DeviceList: NSObject, NSSecureCoding {

    
    // FROM 1.2.0
    // Support iOS 12 secure method for decoding objects
    static var supportsSecureCoding: Bool {
        return true
    }

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

        // FROM 1.2.0
        // Support iOS 12 secure method for decoding objects
        encoder.encode(self.devices as NSArray, forKey: "controller.device.list")
        encoder.encode(NSNumber(value: self.currentDevice), forKey: "controller.current.index")
    }


    required init?(coder decoder: NSCoder) {

        self.currentDevice = -1
        self.devices = []

        // FROM 1.2.0
        // Support iOS 12 secure method for decoding objects
        self.devices = decoder.decodeObject(of: NSArray.self, forKey: "controller.device.list") as! [Device]
        self.currentDevice = decoder.decodeObject(of: NSNumber.self, forKey: "controller.current.index") as! Int
    }

}
