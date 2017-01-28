//
//  VideoSelectController.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 27/01/2017.
//  Copyright © 2017 Open Lab. All rights reserved.
//

import UIKit
import CoreData
import SVProgressHUD
import CryptoSwift
import NSData_FastHex

class VideoSelectController: UITableViewController {
    var cam:Cam?
    var lastFile:URL?
    
    private var videos = [Video]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        do {
            let request = NSFetchRequest<Video>(entityName: "Video")
            request.predicate = NSPredicate(format: "cam == %@", cam!)
            videos = try appDelegate.persistentContainer.viewContext.fetch(request)
        } catch {
            print("Unable to load cams")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videos.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let cam = videos[indexPath.row]
        
        cell.textLabel!.text = cam.timestamp!.description
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = videos[indexPath.row]
        SVProgressHUD.show(withStatus: "Downloading File...")
        URLSession.shared.dataTask(with: URL(string: video.url!)!) { (data, response, error) in
            SVProgressHUD.dismiss()
            if (error == nil){
                do {
                    SVProgressHUD.show(withStatus: "Decrypting File...")
                    let aes = try AES(key: (NSData(hexString: video.key!) as Data).bytes)
                    let paddedBytes = PKCS7().add(to: data!.bytes, blockSize: AES.blockSize)
                    let decrypted = try aes.decrypt(paddedBytes)
                    
                    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).h264")
                    try Data(bytes: decrypted).write(to: fileURL, options: .atomic)
                    
                    SVProgressHUD.dismiss()
                    self.lastFile = fileURL
                    self.performSegue(withIdentifier: "videoSegue", sender: self)
                } catch let aesError {
                    print("Unable to decrypt file: \(aesError)")
                }
            } else {
                print("Error downloading file \(error)")
            }
        }.resume()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier! == "videoSegue" {
            let destination = segue.destination as! VideoController
            destination.path = lastFile
        }
    }
}
