//
//  GradientView.swift
//  RoomPlaner
//
//  Created by Hlib Sobolevskyi on 19.01.2023.
//

import UIKit

class GradientView: UIView {
    
    private var gradientLayer = CAGradientLayer()
    
    @IBInspectable var gradientAlpha: Float {
        get {
            return gradientLayer.opacity
        }
        set {
            gradientLayer.opacity = newValue
        }
    }
    
    var colors: [UIColor] {
        get {
            return gradientLayer.colors!.map({ UIColor(cgColor: $0 as! CGColor)})
        }
        set {
            gradientLayer.colors = newValue.map({ $0.cgColor })
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        gradientLayer.frame = self.frame
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
    
}
