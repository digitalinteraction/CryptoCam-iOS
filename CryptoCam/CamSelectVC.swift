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
import NSDate_TimeAgo

class CamSelectVC: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var placeholderLbl: UILabel!
    private var cams = [Cam]()
    
    private var tappedCam:Cam?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.delegate = self
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
        
        do {
            cams = try context.fetch(NSFetchRequest<Cam>(entityName: "Cam"))
            
            cams = cams.sorted(by: { (c1, c2) -> Bool in
                if let c1l = retrieveLatestVideo(cam: c1) {
                    if let c2l = retrieveLatestVideo(cam: c2) {
                        return c1l.timestamp!.compare(c2l.timestamp! as Date).rawValue > 0
                    } else {
                        return true
                    }
                }
                return false
            })
            
            if cams.count > 0 {
                placeholderLbl.isHidden = true
            } else {
                placeholderLbl.isHidden = false
            }
        } catch {
            print("Unable to load cams")
        }
    }
    
    func refreshCards() {
        loadData()
        collectionView?.reloadData()
        collectionView?.refreshControl?.endRefreshing()
    }
    
    func retrieveLatestVideo(cam: Cam) -> Video? {
        let sorted = (cam.videos as! Set<Video>).sorted(by: { (v1, v2) -> Bool in
            return v1.timestamp!.compare(v2.timestamp! as Date).rawValue > 0
        })
        
        if sorted.count > 1 {
            return sorted[1]
        }
        
        return sorted.first
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cams.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let width = collectionView.layer.frame.size.width
        let cellWidth = CGFloat(175.0)
        return UIEdgeInsets(top: 10, left: (width - (cellWidth * 2)) / 4.0, bottom: 10, right: (width - (cellWidth * 2)) / 4.0)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CamCard", for: indexPath)
        let cam = cams[indexPath.item]
        
        let lastThumbImage = cell.viewWithTag(1) as! UIImageView
        let camNameLbl = cell.viewWithTag(2) as! UILabel
        let lastSeenLbl = cell.viewWithTag(3) as! UILabel
        let locationLbl = cell.viewWithTag(4) as! UILabel
        let activity = cell.viewWithTag(5) as! UIActivityIndicatorView
        
        camNameLbl.text = cam.friendlyName
        locationLbl.text = cam.location
        
        let videoThumb = retrieveLatestVideo(cam: cam)
        
        guard videoThumb != nil else {
            return cell
        }
        
        let thumbUrl = URL(string: videoThumb!.url!)!.appendingPathExtension("jpg")
        
        lastThumbImage.image = nil
        
        DispatchQueue.main.async {
            activity.startAnimating()
        }
        
        SDWebImageManager.shared().cachedImageExists(for: thumbUrl) { (exists) in
            if (exists) {
                DispatchQueue.main.async {
                    lastThumbImage.sd_setImage(with: thumbUrl)
                    activity.stopAnimating()
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
                    DispatchQueue.main.async {
                        activity.stopAnimating()
                    }
                }).resume()
            }
        }
        
        
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lastSeenLbl.text = videoThumb?.timestamp?.timeAgo()
        
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
