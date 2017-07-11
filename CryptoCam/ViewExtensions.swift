//
//  ViewExtensions.swift
//  CryptoCam
//
//  Created by Gerard Wilkinson on 10/07/2017.
//  Copyright © 2017 Open Lab. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    @IBInspectable var borderColor: UIColor {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue.cgColor
        }
    }
}

extension UIButton {
    @IBInspectable var aspectFit: Bool {
        get {
            return imageView?.contentMode == UIViewContentMode.scaleAspectFit
        }
        set {
            imageView?.contentMode = UIViewContentMode.scaleAspectFit
        }
    }
}
