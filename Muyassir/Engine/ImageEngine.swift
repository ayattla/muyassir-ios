import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

enum ImageEngine {
    enum Fmt: String, CaseIterable { case jpg = "JPG", png = "PNG", heic = "HEIC"; var ext: String { rawValue.lowercased() } }
    static let ci = CIContext()

    static func load(_ url: URL, maxSide: CGFloat = 4096) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxSide]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func save(_ img: UIImage, _ fmt: Fmt, quality: CGFloat, to url: URL) throws -> URL {
        let data: Data?
        switch fmt {
        case .jpg: data = flatten(img, .white).jpegData(compressionQuality: quality)
        case .png: data = img.pngData()
        case .heic:
            let d = NSMutableData()
            if let dest = CGImageDestinationCreateWithData(d, "public.heic" as CFString, 1, nil), let cg = img.cgImage {
                CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                data = CGImageDestinationFinalize(dest) ? d as Data : nil
            } else { data = nil }
        }
        guard let data else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url); return url
    }

    static func redraw(_ size: CGSize, _ draw: (CGContext) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { draw($0.cgContext) }
    }

    static func flatten(_ img: UIImage, _ bg: UIColor) -> UIImage {
        redraw(img.size) { c in bg.setFill(); c.fill(CGRect(origin: .zero, size: img.size)); img.draw(at: .zero) }
    }

    static func resize(_ img: UIImage, w: CGFloat, h: CGFloat, keep: Bool) -> UIImage {
        var size = CGSize(width: max(w, 1), height: max(h, 1))
        if keep { let s = min(w / img.size.width, h / img.size.height); size = CGSize(width: max(1, (img.size.width * s).rounded()), height: max(1, (img.size.height * s).rounded())) }
        return redraw(size) { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func rotate(_ img: UIImage, degrees: CGFloat, flipH: Bool = false, flipV: Bool = false) -> UIImage {
        let r = degrees * .pi / 180
        let quarter = Int(degrees / 90) % 2 != 0
        let size = quarter ? CGSize(width: img.size.height, height: img.size.width) : img.size
        return redraw(size) { c in
            c.translateBy(x: size.width / 2, y: size.height / 2); c.rotate(by: r); c.scaleBy(x: flipH ? -1 : 1, y: flipV ? -1 : 1)
            img.draw(in: CGRect(x: -img.size.width / 2, y: -img.size.height / 2, width: img.size.width, height: img.size.height))
        }
    }

    static func cropRatio(_ img: UIImage, _ rw: CGFloat, _ rh: CGFloat) -> UIImage {
        let t = rw / rh, W = img.size.width, H = img.size.height
        let rect = W / H > t ? CGRect(x: (W - H * t) / 2, y: 0, width: H * t, height: H) : CGRect(x: 0, y: (H - W / t) / 2, width: W, height: W / t)
        return crop(img, rect)
    }
    static func cropRect(_ img: UIImage, l: CGFloat, t: CGFloat, r: CGFloat, b: CGFloat) -> UIImage {
        crop(img, CGRect(x: l * img.size.width, y: t * img.size.height, width: (r - l) * img.size.width, height: (b - t) * img.size.height))
    }
    static func crop(_ img: UIImage, _ rect: CGRect) -> UIImage {
        redraw(rect.size) { _ in img.draw(at: CGPoint(x: -rect.minX, y: -rect.minY)) }
    }

    static func adjust(_ img: UIImage, brightness: Double, contrast: Double, saturation: Double, sharpen: Bool, gray: Bool = false) -> UIImage {
        guard var c = CIImage(image: img) else { return img }
        let f = CIFilter.colorControls(); f.inputImage = c; f.brightness = Float(brightness); f.contrast = Float(contrast); f.saturation = gray ? 0 : Float(saturation)
        c = f.outputImage ?? c
        if sharpen { let s = CIFilter.sharpenLuminance(); s.inputImage = c; s.sharpness = 0.5; c = s.outputImage ?? c }
        guard let cg = ci.createCGImage(c, from: c.extent) else { return img }
        return UIImage(cgImage: cg)
    }

    /// Core Image's auto-adjust (exposure, vibrance, tone curve) plus light sharpening.
    static func autoEnhance(_ img: UIImage) -> UIImage {
        guard var c = CIImage(image: img) else { return img }
        for f in c.autoAdjustmentFilters(options: [.redEye: false]) { f.setValue(c, forKey: kCIInputImageKey); c = f.outputImage ?? c }
        let s = CIFilter.sharpenLuminance(); s.inputImage = c; s.sharpness = 0.4; c = s.outputImage ?? c
        guard let cg = ci.createCGImage(c, from: c.extent) else { return img }
        return UIImage(cgImage: cg)
    }

    /// On-device subject lift (Vision foreground instance mask, iOS 17).
    static func removeBackground(_ img: UIImage) throws -> UIImage {
        guard let cg = img.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        let req = VNGenerateForegroundInstanceMaskRequest()
        let h = VNImageRequestHandler(cgImage: cg)
        try h.perform([req])
        guard let res = req.results?.first else { return try personCutout(cg) }
        let buf = try res.generateMaskedImage(ofInstances: res.allInstances, from: h, croppedToInstancesExtent: false)
        let ciImg = CIImage(cvPixelBuffer: buf)
        guard let out = ci.createCGImage(ciImg, from: ciImg.extent) else { throw CocoaError(.fileWriteUnknown) }
        return UIImage(cgImage: out)
    }

    /// Fallback for portraits: Vision person segmentation mask blended over transparency.
    private static func personCutout(_ cg: CGImage) throws -> UIImage {
        let req = VNGeneratePersonSegmentationRequest(); req.qualityLevel = .accurate; req.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try VNImageRequestHandler(cgImage: cg).perform([req])
        guard let maskBuf = req.results?.first?.pixelBuffer else { throw NSError(domain: "mys", code: 1, userInfo: [NSLocalizedDescriptionKey: "لم يُعثر على عنصر واضح في الصورة"]) }
        let src = CIImage(cgImage: cg)
        var mask = CIImage(cvPixelBuffer: maskBuf)
        mask = mask.transformed(by: CGAffineTransform(scaleX: src.extent.width / mask.extent.width, y: src.extent.height / mask.extent.height))
        // An empty mask means no person was found.
        let avg = CIFilter.areaAverage(); avg.inputImage = mask; avg.extent = mask.extent
        var px = [UInt8](repeating: 0, count: 4)
        if let o = avg.outputImage { ci.render(o, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil) }
        if px[0] < 3 { throw NSError(domain: "mys", code: 1, userInfo: [NSLocalizedDescriptionKey: "لم يُعثر على عنصر واضح في الصورة"]) }
        let blend = CIFilter.blendWithMask(); blend.inputImage = src; blend.backgroundImage = CIImage.empty().cropped(to: src.extent); blend.maskImage = mask
        guard let out = blend.outputImage, let res = ci.createCGImage(out, from: src.extent) else { throw CocoaError(.fileWriteUnknown) }
        return UIImage(cgImage: res)
    }

    static func idPhoto(_ img: UIImage, wMm: CGFloat, hMm: CGFloat, bg: UIColor) -> UIImage {
        let size = CGSize(width: (wMm / 25.4 * 300).rounded(), height: (hMm / 25.4 * 300).rounded())
        let c = cropRatio(img, wMm, hMm)
        return redraw(size) { ctx in bg.setFill(); ctx.fill(CGRect(origin: .zero, size: size)); c.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func compressToSize(_ img: UIImage, kb: Int, to url: URL) throws -> URL {
        var cur = flatten(img, .white)
        for _ in 0..<6 {
            var lo: CGFloat = 0.1, hi: CGFloat = 0.95, best: Data? = nil
            for _ in 0..<7 { let q = (lo + hi) / 2; if let d = cur.jpegData(compressionQuality: q), d.count / 1024 <= kb { best = d; lo = q } else { hi = q } }
            if let best { try best.write(to: url); return url }
            cur = resize(cur, w: cur.size.width * 0.8, h: cur.size.height * 0.8, keep: true)
        }
        try cur.jpegData(compressionQuality: 0.1)?.write(to: url); return url
    }

    static func qr(_ text: String, size: CGFloat = 900) -> UIImage {
        let f = CIFilter.qrCodeGenerator(); f.message = Data(text.utf8); f.correctionLevel = "M"
        guard let o = f.outputImage else { return UIImage() }
        let scaled = o.transformed(by: CGAffineTransform(scaleX: size / o.extent.width, y: size / o.extent.height))
        guard let cg = ci.createCGImage(scaled, from: scaled.extent) else { return UIImage() }
        let pad = size * 0.08
        return redraw(CGSize(width: size + 2 * pad, height: size + 2 * pad)) { c in
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: size + 2 * pad, height: size + 2 * pad))
            c.interpolationQuality = .none; UIImage(cgImage: cg).draw(in: CGRect(x: pad, y: pad, width: size, height: size))
        }
    }

    static func readCodes(_ img: UIImage) throws -> [String] {
        guard let cg = img.cgImage else { return [] }
        let req = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: cg).perform([req])
        let found = (req.results ?? []).compactMap { $0.payloadStringValue }
        if !found.isEmpty { return found }
        // Fallback for QR codes (Core Image detector; also works where Vision's barcode model is unavailable).
        let det = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (det?.features(in: CIImage(cgImage: cg)) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }
}

/// Fully on-device text recognition with Apple Vision (Arabic and English).
enum Ocr {
    enum Lang: String, CaseIterable { case ar = "عربي + إنجليزي", en = "إنجليزي فقط" }

    static func recognize(_ img: UIImage, _ lang: Lang) throws -> String {
        guard let cg = img.cgImage else { return "" }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        req.automaticallyDetectsLanguage = false
        req.recognitionLanguages = lang == .ar ? ["ar-SA", "en-US"] : ["en-US"]
        try VNImageRequestHandler(cgImage: cg).perform([req])
        let obs = (req.results ?? []).sorted { a, b in
            abs(a.boundingBox.midY - b.boundingBox.midY) > 0.01 ? a.boundingBox.midY > b.boundingBox.midY : (lang == .ar ? a.boundingBox.midX > b.boundingBox.midX : a.boundingBox.midX < b.boundingBox.midX)
        }
        return obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
