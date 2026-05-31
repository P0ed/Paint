import CoreGraphics

/// Pixel location
struct PxL: Hashable {
    private var _x: Int16
    private var _y: Int16
	private var _z: Int8

    var x: Int { Int(_x) }
    var y: Int { Int(_y) }
	var z: Int { Int(_z) }

	init(x: Int, y: Int, z: Int) {
        _x = Int16(x)
        _y = Int16(y)
		_z = Int8(z & 0b11)
    }

	var neighbors: [PxL] {
		[
			.init(x: x - 1, y: y, z: z),
			.init(x: x + 1, y: y, z: z),
			.init(x: x, y: y - 1, z: z),
			.init(x: x, y: y + 1, z: z),
		]
	}

	var xy: PxL {
		PxL(x: x, y: y, z: 0)
	}

	var isEven: Bool {
		(x & 1 + y & 1) & 1 == 0
	}
}

struct FilmSize: Hashable {
	var width: Int
	var height: Int
	var frames: Int
}

extension FilmSize {

	var count: Int { width * height }

	static var max: FilmSize {
		FilmSize(width: 4096, height: 4096, frames: 1)
	}

	func alloc(color: Px = .clear) -> [Px] {
		.init(repeating: color, count: count * frames)
	}

	func index(at pxl: PxL) -> Int? {
		if pxl.x >= 0 && pxl.x < width && pxl.y >= 0 && pxl.y < height {
			.some(pxl.x + (height - 1 - pxl.y) * width + count * pxl.z)
		} else {
			.none
		}
	}

	func pxl(at index: Int) -> PxL {
		PxL(
			x: index % count % width,
			y: height - 1 - index % count / width,
			z: index / count
		)
	}
}

struct Px: Hashable, Codable {
	var alpha: UInt8
	var red: UInt8
	var green: UInt8
	var blue: UInt8
}

extension Px {

	init(rgb: UInt32) {
		red = UInt8(rgb >> 0 & 0xFF)
		green = UInt8(rgb >> 8 & 0xFF)
		blue = UInt8(rgb >> 16 & 0xFF)
		alpha = 0xFF
	}

	init(rgba: UInt32) {
		red = UInt8(rgba >> 0 & 0xFF)
		green = UInt8(rgba >> 8 & 0xFF)
		blue = UInt8(rgba >> 16 & 0xFF)
		alpha = UInt8(rgba >> 24 & 0xFF)
	}

	var cg: CGColor {
		CGColor(
			red: CGFloat(redf),
			green: CGFloat(greenf),
			blue: CGFloat(bluef),
			alpha: CGFloat(alphaf)
		)
	}

	var alphaf: Float { Float(alpha) / 255.0 }
	var redf: Float { Float(red) / 255.0 }
	var greenf: Float { Float(green) / 255.0 }
	var bluef: Float { Float(blue) / 255.0 }

	static func + (lhs: Px, rhs: Px) -> Px {
		Px(
			alpha: UInt8(clamping: Int(
				(rhs.alphaf + (1.0 - rhs.alphaf) * lhs.alphaf) * 255.0
			)),
			red: UInt8(clamping: Int(
				(rhs.redf + (1.0 - rhs.alphaf) * lhs.redf) * 255.0
			)),
			green: UInt8(clamping: Int(
				(rhs.greenf + (1.0 - rhs.alphaf) * lhs.greenf) * 255.0
			)),
			blue: UInt8(clamping: Int(
				(rhs.bluef + (1.0 - rhs.alphaf) * lhs.bluef) * 255.0
			))
		)
	}
}

extension Px {
	static var white: Self { 0xFFFFFF }
	static var black: Self { 0x000000 }
	static var clear: Self { Px(rgba: 0x0) }
}

struct Palette: Hashable, Codable {
	var colors: [Px]

	subscript(_ idx: Int) -> Px {
		get { colors[idx & 0xF] }
		set { colors[idx & 0xF] = newValue }
	}
}
