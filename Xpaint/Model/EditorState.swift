import SwiftUI

struct EditorState: Equatable {
	var primaryColor: Px = .black
	var secondaryColor: Px = .white
	var tool: Tool = .pencil
	var dither: Bool = false
	var layer: Int = 0
	var visibleLayers: Int = 0b1111
	var size: CGSize = .zero
	var frame: CGRect = .zero
	var scrollPosition: ScrollPosition = .init(point: .zero)
	var magnification: CGFloat = 1.0
	var sizeDialogPresented: Bool = false
	var colorDialogPresented: Bool = false
	var shaderDialogPresented: Bool = false
	var exporting: Bool = false
	var exportedFilm: Film?
}

extension EditorState {

	mutating func setScale(_ scale: CGFloat) {
		let scale = min(max(scale, 0.25), 64.0)
		let frame = frame
		let size = size
		let dm = scale / magnification
		let ds = CGVector(
			dx: frame.width - size.width,
			dy: frame.height - size.height
		)
		let progress = CGVector(
			dx: ds.dx > 0.0 ? (size.width * 0.5 - frame.minX) / frame.width : 0.5,
			dy: ds.dy > 0.0 ? (size.height * 0.5 - frame.minY) / frame.height : 0.5,
		)
		let offset = CGPoint(
			x: (frame.width * dm * progress.dx - size.width * 0.5),
			y: (frame.height * dm * progress.dy - size.height * 0.5)
		)

		magnification = scale
		scrollPosition = .init(point: offset)
	}

	mutating func swapColors() {
		swap(&primaryColor, &secondaryColor)
	}

	var colors: [Px] { [primaryColor, secondaryColor] }

	mutating func toggleLayer() {
		let isVisible = (visibleLayers & (1 << layer)) != 0
		visibleLayers = isVisible
		? visibleLayers & ~(1 << layer)
		: visibleLayers | (1 << layer)
	}

	mutating func prevLayer() {
		layer = (layer - 1) & 0b11
	}

	mutating func nextLayer() {
		layer = (layer + 1) & 0b11
	}
}

enum Tool {
	case pencil, eraser, bucket, replace, eyedropper
}

extension Tool {

	var actionName: String {
		switch self {
		case .pencil: "Pencil"
		case .eraser: "Erase"
		case .bucket: "Bucket"
		case .replace: "Replace"
		case .eyedropper: "Pick color"
		}
	}

	var systemImage: String {
		switch self {
		case .pencil: "pencil"
		case .eraser: "eraser"
		case .bucket: "paint.bucket.classic"
		case .replace: "rectangle.2.swap"
		case .eyedropper: "eyedropper"
		}
	}

	var shortcutCharacter: Character {
		switch self {
		case .pencil: "P"
		case .eraser: "E"
		case .bucket: "B"
		case .replace: "R"
		case .eyedropper: "I"
		}
	}
}

extension EditorState {

	var dialogPresented: Bool {
		colorDialogPresented || sizeDialogPresented || shaderDialogPresented
	}
}
