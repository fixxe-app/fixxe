// Рендерит эмодзи-флаги из currency-data.json в PNG средствами macOS.
//
// Зачем: в Apple Color Emoji, который идёт с runtime iOS Simulator, нет
// глифов флагов (шрифт урезан ~на 50 МБ), поэтому в симуляторе вместо флага
// рисуется «?» в рамке. На реальном iPhone флаги есть. Чтобы скриншоты для
// App Store показывали приложение так, как оно выглядит на устройстве,
// эти PNG подкладываются в DEBUG-бандл (см. FlagAssets) только на время съёмки.
//
// Запуск: swift ios/tools/render-flags.swift <out-dir> [size]

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: render-flags.swift <out-dir> [size]\n".data(using: .utf8)!)
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
let size = args.count > 2 ? Int(args[2])! : 96

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let dataURL = root.appendingPathComponent("ios/FIXXE/Resources/currency-data.json")

struct Raw: Decodable { let flags: [String: String] }
let raw = try JSONDecoder().decode(Raw.self, from: Data(contentsOf: dataURL))

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let font = NSFont(name: "Apple Color Emoji", size: CGFloat(size) * 0.82)!
var written = 0

for (code, emoji) in raw.flags {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = NSAttributedString(string: emoji, attributes: attrs)
    let bounds = str.size()
    str.draw(at: NSPoint(x: (CGFloat(size) - bounds.width) / 2,
                         y: (CGFloat(size) - bounds.height) / 2))
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: outDir.appendingPathComponent("flag_\(code).png"))
    written += 1
}

print("rendered \(written) flags (\(size)px) -> \(outDir.path)")
