//
//  FNCollectionViewCell.swift
//  OGVKit Example
//
//  Created by a_uhankin on 04.07.2018.
//  Copyright © 2018 Brion Vibber. All rights reserved.
//

import SnapKit
import UIKit

private let reuseIdentifier = "Cell"

protocol CollectionController: class {
    func cellActive(cell: VideoCell) -> Bool
}

class CollectionViewController: UICollectionViewController, CollectionController, UICollectionViewDelegateFlowLayout {
    
    var videoSources: [OGVExampleItem] = NSArray.videoArray as Array<OGVExampleItem>;
    
    let loadingQueue = DispatchQueue(label: "com.example.ogvvideo")

    @objc convenience init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal

        self.init(collectionViewLayout: layout)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        collectionView!.register(VideoCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        requestData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func requestData() {
        self.collectionView?.reloadData()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in _: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return videoSources.count
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! VideoCell
        cell.backgroundColor = UIColor.random()
        cell.setupCell()
        cell.controller = self
    
        updateURL(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func updateURL(cell:VideoCell, indexPath:IndexPath) {
        let element = videoSources[indexPath.row]
        cell.videoTitle = element.filename
        loadingQueue.async { [weak cell] in
            guard let cell = cell else { return }
            
            var webMFormat: String?
            element.formats().forEach { (format) in
                if let format = format as? String {
                    if format.lowercased() == "webm".lowercased() {
                        webMFormat = format
                    }
                }
            }
            var maxResolution: Int32?
            if let webMFormat = webMFormat {
                let resolutions = element.resolutions(forFormat: webMFormat)
                if let resolution = resolutions?.last as? Int32 {
                    maxResolution = resolution
                }
            }
            guard cell.videoTitle == element.filename else {return}
            if let format = webMFormat, let resolution = maxResolution {
                cell.url = element.urLforVideoFormat(format, resolution: resolution)
            }
        }
    }

    var activeIndex: Int? {
        guard let collectionView = collectionView else { return nil }
        return Int((collectionView.contentOffset.x / collectionView.bounds.width).rounded())
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let collectionView = collectionView else { return }
        collectionView.visibleCells.forEach({ cell in
            if let videoCell = cell as? VideoCell {
                    videoCell.stop()
            }
        })
    }

    override func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        guard let collectionView = collectionView else { return }
        collectionView.visibleCells.forEach({ cell in
            let activeCellIndex = self.activeIndex
            if let videoCell = cell as? VideoCell {
                if collectionView.indexPath(for: videoCell)?.row == activeCellIndex {
                    videoCell.start()
                } else {
                    videoCell.stop()
                }
            }
        })
    }

    func cellActive(cell: VideoCell) -> Bool {
        let activeCellIndex = activeIndex
        return collectionView?.indexPath(for: cell)?.row == activeCellIndex
    }
    
}

extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static func random() -> UIColor {
        return UIColor(red: .random(),
                       green: .random(),
                       blue: .random(),
                       alpha: 1.0)
    }
}
