import CoreGraphics
import SwiftUI

struct Film: Equatable, Sendable {
	var size: FilmSize
	var pxs: [Px]
}

extension Film {

	init(size: FilmSize, color: Px? = .none) {
		self.size = size
		pxs = size.alloc()
		if let color {
			withMutablePixel(0) { px in px = color }
		}
	}

	init(width: Int = 32, height: Int = 32, frames: Int, color: Px? = .white) {
		self = .init(
			size: FilmSize(width: width, height: height, frames: frames),
			color: color
		)
	}

	var indices: Range<Int> { (0..<size.frames) }

	subscript(_ pxl: PxL) -> Px {
		get {
			size.index(at: pxl).map { idx in pxs[idx] } ?? .clear
		}
		set {
			size.index(at: pxl).map { idx in pxs[idx] = newValue }
		}
	}

	func range(_ layer: Int?) -> Range<Int> {
		layer.map { layer in
			layer * size.count ..< (layer + 1) * size.count
		}
		?? 0 ..< size.count * size.frames
	}

	mutating func withMutableLayer<A>(_ layer: Int, body: (UnsafeMutableBufferPointer<Px>) -> A) -> A {
		pxs.withUnsafeMutableBufferPointer { [rng = range(layer)] ptr in
			body(ptr.extracting(rng))
		}
	}

	mutating func withMutablePixel(_ layer: Int, body: (inout Px) -> Void) {
		withMutableLayer(layer) { ptr in
			for (idx, var px) in ptr.enumerated() {
				body(&px)
				ptr[idx] = px
			}
		}
	}

	mutating func resize(width: Int, height: Int) {
		guard let film = image() else { return }

		var new = Film(width: width, height: height, frames: size.frames, color: .none)
		new.drawFilm(film)

		self = new
	}
}


extension Film {

	mutating func merge(_ f: Film, mask: Int = 0xF) {
		withMutableLayer(0) { [fs = f.size, fc = f.size.count] ptr in
			for frame in f.indices where mask & 1 << frame != 0 {
				for (idx, px) in ptr.enumerated() {
					ptr[idx] = px + f[fs.pxl(at: idx + frame * fc)]
				}
			}
		}
	}
}

extension Film {

	mutating func move(layer: Int, dx: Int = 0, dy: Int = 0, fill: Px = .clear) {
		withMutableLayer(layer) { [size] pxs in
			let xs = dx > 0
			? stride(from: size.width - 1, through: 0, by: -1)
			: stride(from: 0, through: size.width - 1, by: 1)

			let ys = dy > 0
			? stride(from: size.height - 1, through: 0, by: -1)
			: stride(from: 0, through: size.height - 1, by: 1)

			for row in ys {
				for col in xs {
					let x = col + dx
					let y = row + dy

					let src = row * size.width + col
					let dst = y * size.width + x

					if (0..<size.width).contains(x) && (0..<size.height).contains(y) {
						pxs[dst] = pxs[src]
					}
					if x != col || y != row {
						pxs[src] = fill
					}
				}
			}
		}
	}

	mutating func move(layer: Int, dx: Int = 0, dy: Int = 0, fill: Px = .clear, selection: BitSet) {
		let source = Array(pxs[range(layer)])
		withMutableLayer(layer) { [size] pxs in
			for index in selection {
				let column = index % size.width - dx
				let row = index / size.width - dy
				let origin = column + row * size.width
				pxs[index] = (0..<size.width).contains(column)
					&& (0..<size.height).contains(row)
					&& selection[origin]
				? source[origin]
				: fill
			}
		}
	}

	mutating func withFilmContext(
		interpolationQuality: CGInterpolationQuality = .none,
		_ body: (CGContext) -> Void
	) {
		pxs.withUnsafeMutableBytes { [size] ptr in
			if let ctx = CGContext(
				data: ptr.baseAddress,
				width: size.width,
				height: size.height * size.frames,
				bitsPerComponent: 8,
				bytesPerRow: size.width * 4,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
			) {
				ctx.interpolationQuality = interpolationQuality
				body(ctx)
			}
		}
	}

	mutating func drawFilm(_ image: CGImage) {
		withFilmContext { [size] ctx in
			ctx.draw(image, in: CGRect(
				origin: .zero,
				size: CGSize(width: size.width, height: size.height * size.frames)
			))
		}
	}

	func image(_ layer: Int? = .none) -> CGImage? {
		try? pxs[range(layer)].withUnsafeBytes { raw in
			let data = try CFDataCreate(nil, raw.baseAddress, raw.count)
				.throwing("Can't make CFData")
			let provider = try CGDataProvider(data: data)
				.throwing("Can't make CGDataProvider")
			let colorSpace = CGColorSpaceCreateDeviceRGB()
			let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)

			return try CGImage(
				width: size.width,
				height: size.height * (layer == nil ? size.frames : 1),
				bitsPerComponent: 8,
				bitsPerPixel: 32,
				bytesPerRow: size.width * 4,
				space: colorSpace,
				bitmapInfo: bitmapInfo,
				provider: provider,
				decode: nil,
				shouldInterpolate: false,
				intent: .defaultIntent
			)
			.throwing("Can't make CGImage")
		}
	}

	private var layers: [CGImage]? {
		try? indices.map { layer in
			try image(layer).throwing("Can't make CGImage")
		}
	}

	func render(mask: Int, in context: GraphicsContext, size: CGSize) {
		layers?.enumerated().forEach { index, image in
			if mask & 1 << index != 0 {
				context.draw(image.ui, in: CGRect(origin: .zero, size: size))
			}
		}
	}
}

extension Film {

	static var global: Film {
		Film(
			size: .init(width: 0, height: 0, frames: 1),
			pxs: FilmSize.max.alloc()
		)
	}
}
