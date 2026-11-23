// Renders the Mindfulness Bell app icon (Stillwater ripple rings) at 1024px.
// Usage: swift tool/render_icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "app_icon_1024.png"
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setShouldAntialias(true)

// macOS Big Sur icon grid: 824px body centered, soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let path = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x1B2E28, 0.28))
ctx.addPath(path); ctx.setFillColor(rgb(0xE7EFEA)); ctx.fillPath()
ctx.restoreGState()

// Mist gradient (top lighter).
ctx.saveGState()
ctx.addPath(path); ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0xD6E4DC), rgb(0xF3F8F5)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
ctx.restoreGState()

// Ripple rings fading outward.
let c = CGPoint(x: 512, y: 512)
let sage: UInt32 = 0x2F5D50
for (r, w, a) in [(330.0, 9.0, 0.16), (240.0, 15.0, 0.34), (150.0, 22.0, 0.62)] as [(CGFloat, CGFloat, CGFloat)] {
  ctx.setStrokeColor(rgb(sage, a)); ctx.setLineWidth(w)
  ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}
ctx.setFillColor(rgb(sage))
ctx.fillEllipse(in: CGRect(x: c.x - 62, y: c.y - 62, width: 124, height: 124))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
