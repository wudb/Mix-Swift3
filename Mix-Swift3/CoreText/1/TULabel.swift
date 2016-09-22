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
    
    // 文本链接对应的范围
    private var hyperlinkRangeMapper: [String: String] = [:]
    
    var attributedText: NSAttributedString?
    
    // 是否自动检测链接, default is false
    var autoDetectLinks = false
    
    // 指定文本链接映射关系
    var hyperlinkMapper: [String: String]?

    // 链接显示颜色
    var linkColor = UIColor.blue
    
    // 点击链接的回调
    var touchLinkCallback: TouchLinkEvent?

    // 图片附件数组
    var imageAttachments: [TUImageAttachment]?
    
    
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        if self.autoDetectLinks {
            detectLinks()
            self.attributedText = addLinkStyle(attributedText: self.attributedText, links: self.detectLinkList)
        }
        
        if nil != self.hyperlinkMapper {
            self.attributedText = addHyperlinkStyle(attributedText: self.attributedText, links: self.hyperlinkMapper)
        }

        if let attributedString = checkImage(self.attributedText) {
            self.attributedText = attributedString
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
        } else if nil != attributes[TUImageAttachmentAttributeName] {
            drawImage(run: run, attributes: attributes, context: context)
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

        context.strokePath()
    }
    
    // 填充背景色
    func fillBackgroundColor(run: CTRun, attributes: NSDictionary, context: CGContext) {
        let backgroundColor = attributes[NSBackgroundColorAttributeName]
        guard let color = backgroundColor else {
            return
        }
        
        let origin = getRunOrigin(run: run)
        
        var ascent = CGFloat(), descent = CGFloat(), leading = CGFloat()
        let typographicWidth = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading))
        
        let pt = context.textPosition
        
        let rect = CGRect(x: origin.x + pt.x, y: pt.y + origin.y - descent, width: typographicWidth, height: ascent + descent)
        
        let components = (color as! UIColor).cgColor.components!
        context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        context.fill(rect)
    }

    // 检测是否有图片
    func checkImage(_ attributedText: NSAttributedString?) -> NSAttributedString? {
        guard let attrText = attributedText else {
            return attributedText
        }

        guard let attachments = self.imageAttachments else {
            return attrText
        }

        let text = NSMutableAttributedString(attributedString: attrText)

        attachments.forEach { attach in
            text.insert(imageAttribute(for: attach), at: attach.location)
        }

        return text
    }

    // 插入图片样式
    func imageAttribute(for attachment: TUImageAttachment) -> NSAttributedString {
        var imageCallback = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (UnsafeMutableRawPointer) in

        }, getAscent: { pointer -> CGFloat in
            let image = pointer.load(as: UIImage.self)
            return image.size.height / 2
        }, getDescent: { pointer -> CGFloat in
            let image = pointer.load(as: UIImage.self)
            return image.size.height / 2
        }, getWidth: { pointer -> CGFloat in
            let image = pointer.load(as: UIImage.self)
            return image.size.width
        })

        let pointer = UnsafeMutablePointer<UIImage>.allocate(capacity: 1)
        pointer.initialize(to: attachment.image!)
        let runDelegate = CTRunDelegateCreate(&imageCallback, UnsafeMutableRawPointer(pointer))

        pointer.deinitialize()

        //0xFFFC
        let imageAttributedString = NSMutableAttributedString(string: " ")
        imageAttributedString.addAttribute(kCTRunDelegateAttributeName as String, value: runDelegate!, range: NSMakeRange(0, 1))
        imageAttributedString.addAttribute(TUImageAttachmentAttributeName, value: attachment, range: NSMakeRange(0, 1))

        return imageAttributedString
    }

    // 画图片
    func drawImage(run: CTRun, attributes: NSDictionary, context: CGContext) {
        let imageAttachment = attributes[TUImageAttachmentAttributeName]
        guard let attachment = imageAttachment else {
            return
        }
        
        let origin = getRunOrigin(run: run)
        
        var ascent = CGFloat(), descent = CGFloat(), leading = CGFloat()
        let typographicWidth = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading))
        
        let pt = context.textPosition
        
        var rect = CGRect(x: origin.x + pt.x, y: pt.y + origin.y - descent, width: typographicWidth, height: ascent + descent)
        
        let image = (attachment as! TUImageAttachment).image
        rect.size = image!.size
        context.draw(image!.cgImage!, in: rect)
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
            return attributedText
        }
        
        guard let text = attributedText else {
            return attributedText
        }
        
        let attrText = NSMutableAttributedString(attributedString: text)
        linkList.forEach { [unowned self] result in
            attrText.addAttributes([NSForegroundColorAttributeName: self.linkColor,
                NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue,
                NSUnderlineColorAttributeName: self.linkColor], range: result.range)
        }
        return attrText
    }
    
    // 获取行的区域
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
            links.forEach({ [unowned self]result in
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
    
    // 给指定链接的文本添加样式
    func addHyperlinkStyle(attributedText: NSAttributedString?, links: [String: String]?) -> NSAttributedString? {
        guard let linkList = links else {
            return attributedText
        }
        
        guard let text = attributedText else {
            return attributedText
        }
        
        let attrText = NSMutableAttributedString(attributedString: text)
        self.hyperlinkRangeMapper.removeAll()
        
        linkList.forEach { [unowned self] result in
            let attrString = attrText.string as NSString
            let range = attrString.range(of: result.key)
            if range.location != NSNotFound {
                attrText.addAttributes([NSForegroundColorAttributeName: self.linkColor,
                                        NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue,
                                        NSUnderlineColorAttributeName: self.linkColor], range: range)
                
                self.hyperlinkRangeMapper[result.key] = NSStringFromRange(range)
            }
        }
        
        return attrText
    }
    
    // 判断点击的位置是不是链接
    func hyperlinkAtIndex(index: CFIndex) -> String? {
        guard let linkMapper = self.hyperlinkMapper else {
            return nil
        }
        
        var link: String?
        self.hyperlinkRangeMapper.forEach { result in
            let range = NSRangeFromString(result.value)
            if NSLocationInRange(index, range) {
                link = linkMapper[result.key]
                return
            }
        }
        return link
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.autoDetectLinks || nil != self.hyperlinkMapper {
            let touch: UITouch = touches.first!
            let point = touch.location(in: self)
            
            let index = attributedIndexAtPoint(point: point)
            
            // 点击了文本链接
            if nil != self.hyperlinkMapper {
                let link = hyperlinkAtIndex(index: index)
                if nil != link && nil != self.touchLinkCallback {
                    self.touchLinkCallback!(link!)
                }
            }
            
            
            // 点击了自动识别的链接
            if self.autoDetectLinks {
                let foundLink = linkAtIndex(index: index)
                
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
    
    
    
    
}
