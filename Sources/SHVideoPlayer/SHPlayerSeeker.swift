//
//  SHPlayerSeeker.swift
//  PlayerSeekarDemo
//
//  Created by fruitlab on 26/05/17.
//  Copyright © 2020 fruitlab. All rights reserved.
//

import Foundation
import UIKit
//import QuartzCore

//let markUpEventWidthHeight = 21.0 as CGFloat
//let markUpLineHeight = 12.0 as CGFloat//considering 21 as width and 21+12 as height
//let lineWidth = 1.0 as CGFloat
//let animationDuration = 2.0 as Double

protocol SHPlayerSeekerDelegate {
    func didStartMoveSeeker()
    func didEndMoveSeeker(completion: @escaping (_ success:Bool) -> Void)
    func didSingleTouchRecivedOnBar()
    func didTouchesENDAtMAXValue()
}

public class SHPlayerSeeker: UIControl {
    
    var delegate : SHPlayerSeekerDelegate?
    
    private let trackView = UIView()
    private let thumbLayer = SeekerThumbLayer()
    private var previousLocation = CGPoint()
    private let progressYellowLayer = CALayer()
    private let bufferLayer = CALayer()
    
    private var layoutFrame: CGRect = .init(x: 0, y: 0, width: 320, height: 30)
    private var minimumValue: Double = 0.0
    private var maximumValue: Double = 1.0
    
    private var areaForTouchForTrackLayer: CGRect {
//        var rect = trackView.frame
//        rect.origin.x = rect.origin.x - extraAreaForTouchTrackLayer
//        rect.size.width = rect.size.width + extraAreaForTouchTrackLayer*2
//        rect.origin.y = rect.origin.y - extraAreaForTouchTrackLayer
//        rect.size.height = rect.size.height + extraAreaForTouchTrackLayer*2
        return self.frame // rect
    }
    
    private var areaForTouchForThumbSeeker: CGRect {
        var rect = self.thumbLayer.frame
        rect.origin.x = rect.origin.x - extraAreaForTouch
        rect.size.width = rect.size.width + extraAreaForTouch*2
        rect.origin.y = rect.origin.y - extraAreaForTouch
        rect.size.height = rect.size.height + extraAreaForTouch*2
        return rect
    }
    
    
    public var thumbWidth: CGFloat = 20
    public var trackLayerYPosition: CGFloat = 24
    public var trackLayerHeight: CGFloat = 2.0
    public var extraAreaForTouch: CGFloat = 5.0
    public var extraAreaForTouchTrackLayer: CGFloat = 10.0
    
    public var value: Double = 0.0 {
        didSet {
            if value < minimumValue {
                value = minimumValue
            }
            else if value > maximumValue {
                value = maximumValue
            }
            updateThumbPostion()
            
        }
    }
    
    public var bufferValue: Double = 0.0 {
        didSet {
            if value < minimumValue {
                value = minimumValue
            }
            else if value > maximumValue {
                value = maximumValue
            }
            updateBufferLayerFrame()
        }
    }
    
    public var thumbColor: UIColor = .clear {
        didSet {
            thumbLayer.backgroundColor = thumbColor.cgColor
        }
    }
    
    public override var backgroundColor: UIColor? {
        didSet {
            trackView.backgroundColor = backgroundColor
        }
    }
    
    public var bufferColor: UIColor = .clear {
        didSet {
            bufferLayer.backgroundColor = bufferColor.cgColor
        }
    }
    
    public var progressColor: UIColor = .clear {
        didSet {
            progressYellowLayer.backgroundColor = progressColor.cgColor
        }
    }

    
    // MARK: init
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.intiallizeLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.intiallizeLayers()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutFrame = self.bounds
//        updateLayerFrames()
    }
    
    private func intiallizeLayers() {
        
        trackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackView)
        let constraints = [
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.heightAnchor.constraint(equalToConstant: trackLayerHeight),
            trackView.topAnchor.constraint(equalTo: topAnchor, constant: trackLayerYPosition)
        ]
        NSLayoutConstraint.activate(constraints)
        
        
        trackView.layer.addSublayer(bufferLayer)
        trackView.layer.addSublayer(progressYellowLayer)
        
        layer.addSublayer(thumbLayer)
        thumbLayer.seekerSlider = self
        thumbLayer.cornerRadius = thumbWidth/2
        self.addGesture()
        
    }
    
    private func addGesture() {
        var tapGesture: UITapGestureRecognizer?
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture))
        tapGesture?.cancelsTouchesInView = false
        self.addGestureRecognizer(tapGesture!)
    }
    
    @objc private func handleGesture(sender: UITapGestureRecognizer) -> Void {
        let point = sender.location(in: self)
        if areaForTouchForTrackLayer.contains(point) {
            //thumbLayer.highlighted = true
            //print("touch recived On trackLayer Layer")
            
            let deltaLocation = Double(point.x) - Double(thumbWidth/2) //working fine ratio is Double(bounds.width - thumbWidth)
            let deltaValue = (maximumValue - minimumValue) * deltaLocation / Double(layoutFrame.width - thumbWidth)
            value = boundValue(value: deltaValue, toLowerValue: minimumValue, upperValue: maximumValue)
            
//            updateLayerFrames()
            thumbLayer.highlighted = false /*to avoid calling tracking methods*/
            
            self.delegate?.didSingleTouchRecivedOnBar()
            if self.value == self.maximumValue {
                self.delegate?.didTouchesENDAtMAXValue()
            }
            
        }
        
    }
    
    
    /*
    func updateLayerFrames() {
        
        trackLayer.frame = CGRect(x: 0.0, y: trackLayerYPosition, width: layoutFrame.width, height: trackLayerHeight)
        trackLayer.setNeedsDisplay()
        
    }
    */
    
    
    private func updateBufferLayerFrame() {
        
        let thumbCenter2 = CGFloat(positionForBufferValue(bufferValue))
        if !thumbCenter2.isNormal {
            return
        }
        
        bufferLayer.frame = CGRect(x: 0.0, y: 0.0, width: thumbCenter2, height: trackLayerHeight)
        bufferLayer.setNeedsDisplay()
        
    }
    
    private func updateThumbPostion() {
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let thumbCenter = CGFloat(positionForValue(value))
        let thumbY = trackLayerYPosition-(thumbWidth-trackLayerHeight)/2
        if !thumbCenter.isNormal {
            return
        }
        
        thumbLayer.frame = CGRect(x: thumbCenter - thumbWidth / 2.0, y: thumbY, width: thumbWidth, height: thumbWidth)
        thumbLayer.setNeedsDisplay()
        
        progressYellowLayer.frame = CGRect(x: 0.0, y: 0.0, width: thumbCenter - thumbWidth / 2.0, height: trackLayerHeight)
        progressYellowLayer.setNeedsDisplay()
        
        CATransaction.commit()
        
    }
    
    
    private func positionForValue(_ value: Double) -> Double {
        return Double(layoutFrame.width - thumbWidth) * (value - minimumValue) /
            (maximumValue - minimumValue) + Double(thumbWidth / 2.0)
    }
    
    private func positionForBufferValue(_ value: Double) -> Double {
        return Double(layoutFrame.width) * (value - minimumValue) / (maximumValue - minimumValue)
    }
    
    
    public func displayThumb(isOff: Bool) {
        thumbLayer.isHidden = isOff
    }
    
}

extension SHPlayerSeeker {
    
    func boundValue(value: Double, toLowerValue lowerValue: Double, upperValue: Double) -> Double {
        return min(max(value, lowerValue), upperValue)
    }
    
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        previousLocation = touch.location(in: self)
        
        // Hit test the thumb layers
        if areaForTouchForTrackLayer.contains(previousLocation) {
            thumbLayer.highlighted = true
            self.delegate?.didStartMoveSeeker()
        }
        return thumbLayer.highlighted
    }
    
    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        
        // 1. Determine by how much the user has dragged
        // let deltaLocation = Double(location.x - previousLocation.x)
        let deltaLocation = Double(location.x) - Double(thumbWidth/2) //working fine ratio is Double(bounds.width - thumbWidth)
        let deltaValue = (maximumValue - minimumValue) * deltaLocation / Double(layoutFrame.width - thumbWidth)
        
        previousLocation = location
        
        // 2. Update the values
        if thumbLayer.highlighted {
            value = boundValue(value: deltaValue, toLowerValue: minimumValue, upperValue: maximumValue)
        }
        
        sendActions(for: .valueChanged)
        
        return true
    }
    
    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if thumbLayer.highlighted == true { //sometimes called when perform gesture sequence
            thumbLayer.highlighted = false
            self.delegate?.didEndMoveSeeker(completion: { (success) in
            })
            if self.value == self.maximumValue {
                self.delegate?.didTouchesENDAtMAXValue()
            }
        }
    }
    
    
}

class SeekerThumbLayer: CALayer {
    var highlighted = false
    weak var seekerSlider: SHPlayerSeeker?
}

