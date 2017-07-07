//
//  VideoController.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 27/01/2017.
//  Copyright © 2017 Open Lab. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class VideoPlayerVC: AVPlayerViewController {
    var path:URL?
    
    override func viewDidAppear(_ animated: Bool) {
        player = AVPlayer(url: path!)
        player?.play()
    }
}
