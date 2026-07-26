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

/// Directions a snapped line may take, ordered so that ties resolve to the earliest entry.
private let snapDirections = [
	(x: -1, y: 0), (x: 1, y: 0),
	(x: -2, y: -1), (x: -2, y: 1), (x: 2, y: -1), (x: 2, y: 1),
	(x: -1, y: -1), (x: -1, y: 1), (x: 1, y: -1), (x: 1, y: 1),
	(x: -1, y: -2), (x: -1, y: 2), (x: 1, y: -2), (x: 1, y: 2),
	(x: 0, y: -1), (x: 0, y: 1),
]

extension [PxL] {
	/// Bresenham rasterization of the pixels between `start` and `end`, on `start`'s layer.
	static func rasterizedLine(from start: PxL, to end: PxL) -> [PxL] {
		var result: [PxL] = []
		var x = start.x
		var y = start.y
		let dx = abs(end.x - start.x)
		let sx = start.x < end.x ? 1 : -1
		let dy = -abs(end.y - start.y)
		let sy = start.y < end.y ? 1 : -1
		var error = dx + dy
		result.reserveCapacity(Swift.max(dx, -dy) + 1)

		while true {
			result.append(PxL(x: x, y: y, z: start.z))
			if x == end.x, y == end.y { break }
			let doubled = 2 * error
			if doubled >= dy {
				error += dy
				x += sx
			}
			if doubled <= dx {
				error += dx
				y += sy
			}
		}
		return result
	}
}

extension PxL {

	func snappedEndpoint(to end: PxL) -> PxL {
		let dx = end.x - x
		let dy = end.y - y
		guard dx != 0 || dy != 0 else { return end }

		let deltaLength = Double(dx * dx + dy * dy)
		var best = (x: 1, y: 0)
		var bestScore = -Double.infinity

		for direction in snapDirections {
			let dot = Double(dx * direction.x + dy * direction.y)
			guard dot > 0 else { continue }
			let directionLength = Double(direction.x * direction.x + direction.y * direction.y)
			let score = dot / (deltaLength * directionLength).squareRoot()
			if score > bestScore {
				bestScore = score
				best = direction
			}
		}

		let lengthSquared = best.x * best.x + best.y * best.y
		let multiple = max(1, Int((Double(dx * best.x + dy * best.y) / Double(lengthSquared)).rounded()))
		let overshootX = abs(best.x) == 2 ? best.x.signum() : 0
		let overshootY = abs(best.y) == 2 ? best.y.signum() : 0

		return PxL(
			x: x + best.x * multiple + overshootX,
			y: y + best.y * multiple + overshootY,
			z: z
		)
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
