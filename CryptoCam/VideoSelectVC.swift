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
import SDWebImage

class VideoSelectVC: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    var cam:Cam?
    var lastFile:URL?
    
    private var videos = [Video]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.delegate = self
        collectionView?.alwaysBounceVertical = true
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshCards), for: .valueChanged)
        collectionView?.refreshControl = refresh
        
        navigationItem.title = cam?.friendlyName
        
        loadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        do {
            let request = NSFetchRequest<Video>(entityName: "Video")
            request.predicate = NSPredicate(format: "cam == %@", cam!)
            videos = try appDelegate.persistentContainer.viewContext.fetch(request)
            
            videos = videos.sorted(by: { (v1, v2) -> Bool in
                return v1.timestamp!.compare(v2.timestamp! as Date).rawValue > 0
            })
        } catch {
            print("Unable to load cams: \(error)")
        }
    }
    
    func refreshCards() {
        loadData()
        collectionView?.reloadData()
        collectionView?.refreshControl?.endRefreshing()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCard", for: indexPath)
        let video = videos[indexPath.item]
        
        let thumbImage = cell.viewWithTag(1) as! UIImageView
        let dateLbl = cell.viewWithTag(2) as! UILabel
        let activity = cell.viewWithTag(3) as! UIActivityIndicatorView
        let playBtn = cell.viewWithTag(4) as! UIButton
        
        let thumbUrl = URL(string: video.url!)!.appendingPathExtension("jpg")
        
        thumbImage.image = nil
        
        DispatchQueue.main.async {
            activity.startAnimating()
        }
        
        SDWebImageManager.shared().cachedImageExists(for: thumbUrl) { (exists) in
            if (exists) {
                DispatchQueue.main.async {
                    thumbImage.sd_setImage(with: thumbUrl)
                    activity.stopAnimating()
                    playBtn.isHidden = false
                }
            } else {
                print("Retrieving thumb: \(thumbUrl)")
                URLSession.shared.dataTask(with: thumbUrl, completionHandler: { (data, response, error) in
                    if let error = error {
                        print("Unable to download thumb: \(error)")
                    } else if let data = data {
                        let decrypted = Cryptor.decryptThumbBytes(video: video, data: data)
                        if let decrypted = decrypted {
                            let modifiedImage = UIImage(data: decrypted)
                            SDWebImageManager.shared().saveImage(toCache: modifiedImage, for: thumbUrl)
                            DispatchQueue.main.async {
                                thumbImage.sd_setImage(with: thumbUrl)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        activity.stopAnimating()
                        playBtn.isHidden = false
                    }
                }).resume()
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateLbl.text = formatter.string(from: video.timestamp! as Date)
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let video = videos[indexPath.item]
        SVProgressHUD.show(withStatus: "Downloading Video...")
        Cryptor.decryptVideo(video: video) { (url, error) in
            if let error = error, url != nil {
                let alert = UIAlertController(title: "Download Failed", message: "Error downloading or processing file.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    self.present(alert, animated: true, completion: nil)
                }
                print (error)
            } else if let url = url {
                self.lastFile = url
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    self.performSegue(withIdentifier: "videoSegue", sender: self)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier! == "videoSegue" {
            let destination = segue.destination as! VideoPlayerVC
            destination.path = lastFile
        }
    }
}
