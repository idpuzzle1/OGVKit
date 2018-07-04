//
//  FNCollectionViewCell.swift
//  OGVKit Example
//
//  Created by a_uhankin on 04.07.2018.
//  Copyright © 2018 Brion Vibber. All rights reserved.
//

import UIKit

class VideoCell: UICollectionViewCell, OGVPlayerDelegate {
    weak var controller: CollectionController?
    
    var videoTitle: String?
    
    private weak var videoPlayer: OGVPlayerView?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stop()
        url = nil
    }
    
    var url: URL? {
        willSet {
            guard let inputStream = videoPlayer?.inputStream else { return }
            inputStream.cancel()
        }
        didSet {
            if let url = url {
                videoPlayer?.sourceURL = url
                videoPlayer?.play()
                //videoPlayer?.inputStream = OGVInputStream(url: url)
                //videoPlayer?.play()
            }
        }
    }
    
    var data: Data? {
        willSet {
            guard let inputStream = videoPlayer?.inputStream else { return }
            inputStream.cancel()
        }
        didSet {
            if let data = data {
                videoPlayer?.inputStream = OGVInputStream(data: data)
                videoPlayer?.play()
            }
        }
    }
    
    func setupCell() {
        guard videoPlayer == nil else { return }
        
        let player = OGVPlayerView(frame: .zero)
        player.delegate = self
        addSubview(player)
        player.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.left.greaterThanOrEqualToSuperview()
            make.bottom.right.lessThanOrEqualToSuperview()
            make.size.greaterThanOrEqualTo(CGSize(width: 300, height: 150))
        }
        videoPlayer = player
    }
    
    func start() {
        videoPlayer?.play()
    }
    
    func stop() {
        videoPlayer?.pause()
        // videoPlayer?.seek(0)
    }
    
    internal func ogvPlayerDidLoadMetadata(_ sender: OGVPlayerView!) {
        guard let controller = controller else { return }
        if controller.cellActive(cell: self) {
            videoPlayer?.play()
        }
    }
    
    internal func ogvPlayerDidEnd(_: OGVPlayerView!) {
        videoPlayer?.seek(0)
        guard let controller = controller else { return }
        if controller.cellActive(cell: self) {
            videoPlayer?.play()
        }
    }
}
