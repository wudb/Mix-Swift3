//
//  CoreText1View.swift
//  Mix
//
//  Created by nc-wudb on 16/8/29.
//  Copyright © 2016年 wudb. All rights reserved.
//

import UIKit

// 点击链接的回调
typealias TouchLinkEvent = (_ link: String) -> Void

class TULabel: UIView {
    private var ctframe: CTFrame?
    
    // 检测到的链接
    private var detectLinkList: [NSTextCheckingResult]?
    
    var attributedText: NSAttributedString?
    
    // 是否自动检测链接, default is false
    var autoDetectLinks = false
    
    // 链接显示颜色
    var linkColor = UIColor.blue
    
    // 点击链接的回调
    var touchLinkCallback: TouchLinkEvent?
    
    
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        
        if self.autoDetectLinks {
            detectLinks()
            self.attributedText = addLinkStyle(attributedText: self.attributedText, links: self.detectLinkList)
        }
        
        guard let text = self.attributedText else {
            return
        }
        
        // 1.获取当前上下文
        let context = UIGraphicsGetCurrentContext()!
        
        // 2.转换坐标系
        context.textMatrix = .identity//CGAffineTransformIdentity
        context.translateBy(x: 0, y: self.bounds.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 3.初始化路径
        let path = CGPath(rect: self.bounds, transform: nil)
        
        // 4.初始化字符串
//        let attrString = NSMutableAttributedString(string: str)
//        attrString.addAttribute(NSForegroundColorAttributeName, value: UIColor.whiteColor(), range: NSMakeRange(0, attrString.length))
        
        // 5.初始化framesetter
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        
        // 6.绘制frame
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, text.length), path, nil)
        self.ctframe = frame
    
        // 获得CTLine数组
        let lines = CTFrameGetLines(frame)
        
        // 获得行数
        let numberOfLines = CFArrayGetCount(lines)
        
        // 获得每一行的origin, CoreText的origin是在字形的baseLine处的
        var lineOrigins = [CGPoint](repeating: CGPoint(x: 0, y: 0), count: numberOfLines)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigins)
        
//        var lineAscent = CGFloat(), lineDescent = CGFloat(), lineLeading = CGFloat()
        
        // 遍历每一行进行绘制
        for index in 0..<numberOfLines {
            let origin = lineOrigins[index]
            
            // 参考: http://swifter.tips/unsafe/
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, index), to: CTLine.self)
            
//            CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading)
            
            context.textPosition = CGPoint(x: origin.x, y: origin.y)
//            CGContextSetTextPosition(context, origin.x, origin.y)
            
//            CTLineDraw(line, context)
            
            drawLine(line: line, context: context)
        }
        
//        CTFrameDraw(frame, context!)
    }
    
    // 画一行
    func drawLine(line: CTLine, context: CGContext) {
        let runs = CTLineGetGlyphRuns(line) as Array
    
        runs.forEach { run in
            
            let attributes = CTRunGetAttributes(run as! CTRun) as NSDictionary
            
            drawRun(run: run as! CTRun, attributes: attributes, context: context)
        }
        
    }
    
    // 画样式
    func drawRun(run: CTRun, attributes: NSDictionary, context: CGContext) {
        if nil != attributes[NSStrikethroughStyleAttributeName] { // 删除线
            CTRunDraw(run, context, CFRangeMake(0, 0))
            drawStrikethroughStyle(run: run, attributes: attributes, context: context)
        } else if nil != attributes[NSBackgroundColorAttributeName] { // 背景色
            fillBackgroundColor(run: run, attributes: attributes, context: context)
            CTRunDraw(run, context, CFRangeMake(0, 0))
        } else {
            CTRunDraw(run, context, CFRangeMake(0, 0))
        }
    }
    
    // 获取Run原点
    func getRunOrigin(run: CTRun) -> CGPoint {
        var origin = CGPoint.zero
        let firstGlyphPosition = CTRunGetPositionsPtr(run)
        if nil == firstGlyphPosition {
            let positions = UnsafeMutablePointer<CGPoint>.allocate(capacity: 1)
            
            positions.initialize(to: CGPoint(x: 0, y: 0))
            CTRunGetPositions(run, CFRangeMake(0, 0), positions)
            origin = positions.pointee
            
            positions.deinitialize()
        } else {
            origin = firstGlyphPosition!.pointee
        }
        
        return origin
    }
    
    // 获得run的字体
    func getRunFont(attributes: NSDictionary) -> UIFont {
        return (attributes[NSFontAttributeName] ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)) as! UIFont
    }
    
    // 画删除线
    func drawStrikethroughStyle(run: CTRun, attributes: NSDictionary, context: CGContext) {
        // 获取删除线样式
        let styleRef = attributes[NSStrikethroughStyleAttributeName]//unsafeBitCast(CFDictionaryGetValue(attributes, NSStrikethroughStyleAttributeName), CFNumber.self)
        var style: NSUnderlineStyle = .styleNone
        CFNumberGetValue(styleRef as! CFNumber, CFNumberType.sInt64Type, &style)
        
        guard style != .styleNone else {
            return
        }
        
        // 画线的宽度
        var lineWidth: CGFloat = 1
        if (style.rawValue & NSUnderlineStyle.styleThick.rawValue) == NSUnderlineStyle.styleThick.rawValue {
            lineWidth *= 2
        }
        
        context.setLineWidth(lineWidth)
        
        
        // 获取画线的起点
        let firstPosition = getRunOrigin(run: run)
        
        // 开始画
        context.beginPath()
        
        // 线的颜色
        let lineColor = attributes[NSStrikethroughColorAttributeName]
        if nil == lineColor {
            context.setStrokeColor(UIColor.black.cgColor)
        } else {
            context.setStrokeColor((lineColor as! UIColor).cgColor)
        }
        
        // 字体高度
        let font = getRunFont(attributes: attributes)
        var strikeHeight: CGFloat = font.xHeight / 2.0 + firstPosition.y
        
        // 多行调整
        let pt = context.textPosition
        strikeHeight += pt.y
        
        // 画线的宽度
//        var ascent = CGFloat(), descent = CGFloat(), leading = CGFloat()
        let typographicWidth = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), nil, nil, nil))
        
        context.move(to: CGPoint(x: pt.x + firstPosition.x, y: strikeHeight))
        context.addLine(to: CGPoint(x: pt.x + firstPosition.x + typographicWidth, y: strikeHeight))
//        CGContextMoveToPoint(context, pt.x + firstPosition.x, strikeHeight)
//        CGContextAddLineToPoint(context, pt.x + firstPosition.x + typographicWidth, strikeHeight)
        
        context.strokePath()
    }
    
    // 填充背景色
    func fillBackgroundColor(run: CTRun, attributes: NSDictionary, context: CGContext) {
        let backgroundColor = attributes[NSBackgroundColorAttributeName]
        guard let color = backgroundColor else {
            return
        }
        
        let origin = getRunOrigin(run: run)
        
        let font = getRunFont(attributes: attributes)
        
        var ascent = CGFloat(), descent = CGFloat(), leading = CGFloat()
        let typographicWidth = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading))
        
        let pt = context.textPosition
        
        let rect = CGRect(x: origin.x + pt.x, y: pt.y + origin.y - descent, width: typographicWidth, height: font.xHeight + ascent + descent)
        
        let components = (color as! UIColor).cgColor.components!
        context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        context.fill(rect)
    }
    
    // 检测链接
    func detectLinks() {
        guard let text = self.attributedText else {
            return
        }
        
        let linkDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        
        let content = text.string
        self.detectLinkList = linkDetector.matches(in: content, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, content.characters.count))
    }
    
    // 给链接增加样式
    func addLinkStyle(attributedText: NSAttributedString?, links: [NSTextCheckingResult]?) -> NSAttributedString? {
        guard let linkList = links else {
            return nil
        }
        
        guard let text = attributedText else {
            return nil
        }
        
        let attrText = NSMutableAttributedString(attributedString: text)
        linkList.forEach { [unowned self] result in
            attrText.addAttributes([NSForegroundColorAttributeName: self.linkColor,
                NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue,
                NSUnderlineColorAttributeName: self.linkColor], range: result.range)
        }
        return attrText
    }
    
    //
    func getLineRect(line: CTLine, origin: CGPoint) -> CGRect {
        var ascent = CGFloat(), descent = CGFloat(), leading = CGFloat()
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading));
        let height = ascent + descent;
        
        return CGRect(x: origin.x, y: origin.y - descent, width: width, height: height);
    }
    
    // 获取点击位置对应的富文本的位置index
    func attributedIndexAtPoint(point: CGPoint) -> CFIndex {
        guard let frame = self.ctframe else {
            return -1
        }
        
        let lines = CTFrameGetLines(frame)
        
        // 获得行数
        let numberOfLines = CFArrayGetCount(lines)
        
        // 获得每一行的origin, CoreText的origin是在字形的baseLine处的
        var lineOrigins = [CGPoint](repeating: CGPoint(x: 0, y: 0), count: numberOfLines)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigins)
        
        //坐标变换
        let transform = CGAffineTransform(translationX: 0, y: self.bounds.size.height).scaledBy(x: 1, y: -1);
        
        for index in 0..<numberOfLines {
            let origin = lineOrigins[index]
            
            // 参考: http://swifter.tips/unsafe/
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, index), to: CTLine.self)
            
            let flippedRect = getLineRect(line: line, origin: origin)
            let rect = flippedRect.applying(transform)
            
            if rect.contains(point) { // 找到了是哪一行
                let relativePoint = CGPoint(x: point.x - rect.minX, y: point.y - rect.minY)
                return CTLineGetStringIndexForPosition(line, relativePoint)
            }
        }
        
        return -1
    }
    
    // 判断点击的位置是不是链接
    func linkAtIndex(index: CFIndex) -> (foundLink: NSTextCheckingResult?, link: String?) {
        if self.autoDetectLinks {
            guard let links = self.detectLinkList else {
                return (nil, nil)
            }
            
            var foundLink: NSTextCheckingResult?
            var link: String?
            links.forEach({ result in
                if NSLocationInRange(index, result.range) {
                    foundLink = result
                    link = self.attributedText!.attributedSubstring(from: result.range).string
                    return
                }
            })
            return (foundLink, link)
        }
        
        return (nil, nil)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.autoDetectLinks {
            let touch: UITouch = touches.first!
            let point = touch.location(in: self)
            
            let foundLink = linkAtIndex(index: attributedIndexAtPoint(point: point))
            
            if nil != foundLink.foundLink  {
                guard let link = foundLink.link else {
                    return
                }
                
                if let touchLink = self.touchLinkCallback {
                    touchLink(link)
                }
            }
        }
    }
    
    
    
    
    
    
}
