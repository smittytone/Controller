
//  Created by Tony Smith on 06/12/2016.
//  Copyright © 2016-17 Tony Smith. All rights reserved.


import Foundation


class Connexion: NSObject {

    var task: URLSessionTask?
    var data: NSMutableData?
    var actionCode: Int = -1
    var errorCode: Int = -1

}
