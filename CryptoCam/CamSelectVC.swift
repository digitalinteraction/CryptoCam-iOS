//
//  CamSelectController.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 30/10/2016.
//  Copyright © 2016 Open Lab. All rights reserved.
//

import UIKit
import CoreData
import SDWebImage

class CamSelectVC: UICollectionViewController {
    private var cams = [Cam]()
    
    private var tappedCam:Cam?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.alwaysBounceVertical = true
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshCards), for: .valueChanged)
        
        collectionView?.refreshControl = refresh
        
        loadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(camDataUpdated), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: context)
        
        do {
            cams = try context.fetch(NSFetchRequest<Cam>(entityName: "Cam"))
        } catch {
            print("Unable to load cams")
        }
    }
    
    func refreshCards() {
        loadData()
        collectionView?.reloadData()
        collectionView?.refreshControl?.endRefreshing()
    }
    
    func camDataUpdated() {
        refreshCards()
    }
    
    func retrieveLatestVideo(cam: Cam) -> Video? {
        let sorted = (cam.videos as! Set<Video>).sorted(by: { (v1, v2) -> Bool in
            return v1.timestamp!.compare(v2.timestamp! as Date).rawValue > 0
        })
        
        return sorted.first
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cams.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CamCard", for: indexPath)
        let cam = cams[indexPath.item]
        
        let lastThumbImage = cell.viewWithTag(1) as! UIImageView
        let camNameLbl = cell.viewWithTag(2) as! UILabel
        let lastSeenLbl = cell.viewWithTag(3) as! UILabel
        let locationLbl = cell.viewWithTag(4) as! UILabel
        
        camNameLbl.text = cam.name
        
        let videoThumb = retrieveLatestVideo(cam: cam)
        
        guard videoThumb != nil else {
            return cell
        }
        
        let thumbUrl = URL(string: videoThumb!.url!)!.appendingPathExtension("jpg")
        
        SDWebImageManager.shared().cachedImageExists(for: thumbUrl) { (exists) in
            if (exists) {
                DispatchQueue.main.async {
                    lastThumbImage.sd_setImage(with: thumbUrl)
                }
            } else {
                print("Retrieving thumb: \(thumbUrl)")
                URLSession.shared.dataTask(with: thumbUrl, completionHandler: { (data, response, error) in
                    if let error = error {
                        print("Unable to download thumb: \(error)")
                    } else if let data = data {
                        let decrypted = Cryptor.decryptThumbBytes(video: videoThumb!, data: data)
                        if let decrypted = decrypted {
                            let modifiedImage = UIImage(data: decrypted)
                            SDWebImageManager.shared().saveImage(toCache: modifiedImage, for: thumbUrl)
                            DispatchQueue.main.async {
                                lastThumbImage.sd_setImage(with: thumbUrl)
                            }
                        }
                    }
                }).resume()
            }
        }
        
        
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lastSeenLbl.text = formatter.string(from: videoThumb!.timestamp! as Date)
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cam = cams[indexPath.item]
        tappedCam = cam
        performSegue(withIdentifier: "camSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier! == "camSegue" {
            let destination = segue.destination as! VideoSelectVC
            destination.cam = tappedCam
        }
    }
}
