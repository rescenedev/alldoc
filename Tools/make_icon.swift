import AppKit

// AllDoc 앱 아이콘을 그려 1024x1024 PNG 로 저장한다.
// 사용: swift make_icon.swift <출력경로.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext
let rect = CGRect(x: 0, y: 0, width: size, height: size)

// 둥근 사각형 배경 + 그라데이션 (macOS 아이콘 느낌).
let radius: CGFloat = CGFloat(size) * 0.225
let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40),
                          xRadius: radius, yRadius: radius)
bgPath.addClip()
let colors = [
    NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.95, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.10, green: 0.30, blue: 0.78, alpha: 1).cgColor,
]
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: size, y: 0),
                       options: [])

// 겹친 문서 카드 3장.
func card(_ rect: CGRect, _ color: NSColor, rotation: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: rect.midX, y: rect.midY)
    ctx.rotate(by: rotation * .pi / 180)
    ctx.translateBy(x: -rect.midX, y: -rect.midY)
    let p = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    color.setFill()
    p.fill()
    ctx.restoreGState()
}

let cardSize = CGSize(width: 380, height: 480)
let cx = CGFloat(size) / 2
let cy = CGFloat(size) / 2
let base = CGRect(x: cx - cardSize.width/2, y: cy - cardSize.height/2,
                  width: cardSize.width, height: cardSize.height)

card(base, NSColor.white.withAlphaComponent(0.30), rotation: -14)
card(base, NSColor.white.withAlphaComponent(0.55), rotation: -6)
card(base, NSColor.white, rotation: 2)

// 맨 앞 카드 위의 텍스트 라인 + 돋보기.
ctx.saveGState()
ctx.translateBy(x: base.midX, y: base.midY)
ctx.rotate(by: 2 * .pi / 180)
ctx.translateBy(x: -base.midX, y: -base.midY)
let lineColor = NSColor(calibratedWhite: 0.78, alpha: 1)
lineColor.setFill()
for i in 0..<4 {
    let y = base.maxY - 130 - CGFloat(i) * 64
    let w = (i == 3) ? base.width * 0.45 : base.width * 0.66
    let line = NSBezierPath(roundedRect: CGRect(x: base.minX + 60, y: y, width: w, height: 26),
                            xRadius: 13, yRadius: 13)
    line.fill()
}
ctx.restoreGState()

// 돋보기 (검색 강조).
let glassCenter = CGPoint(x: base.maxX - 70, y: base.minY + 120)
let glassRadius: CGFloat = 96
let accent = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.15, alpha: 1)
accent.setStroke()
let ring = NSBezierPath(ovalIn: CGRect(x: glassCenter.x - glassRadius, y: glassCenter.y - glassRadius,
                                       width: glassRadius*2, height: glassRadius*2))
ring.lineWidth = 34
ring.stroke()
let handle = NSBezierPath()
handle.move(to: CGPoint(x: glassCenter.x - glassRadius*0.7, y: glassCenter.y - glassRadius*0.7))
handle.line(to: CGPoint(x: glassCenter.x - glassRadius*1.35, y: glassCenter.y - glassRadius*1.35))
handle.lineWidth = 40
handle.lineCapStyle = .round
handle.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG 생성 실패\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("아이콘 저장: \(outPath)")
