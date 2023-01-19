//
//  RoomObjectCollectionViewCell.swift
//  RoomPlaner
//
//  Created by Hlib Sobolevskyi on 19.01.2023.
//

import UIKit

class RoomObjectCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "roomObject"
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var name: UILabel!
    
    func setup(with image: UIImage?, name: String) {
        if image != nil {
            self.imageView.image = image
        }
        self.name.text = name
    }
}
