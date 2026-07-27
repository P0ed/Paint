import SwiftUI

struct EditorState: Equatable {
	var primaryColor: Px = .black
	var secondaryColor: Px = .white
	var tool: Tool = .pencil {
		didSet {
			guard tool != oldValue else { return }
			cancelSessions()
		}
	}
	var dither: Bool = false
	var selection: Selection = .none
	var selectionSession: SelectionSession?
	var lineSession: LineSession?
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

enum SelectionMode: Equatable {
	case replace, union, subtract

	init(shift: Bool, option: Bool) {
		self = option ? .subtract : shift ? .union : .replace
	}
}

struct SelectionSession: Equatable {
	var start: PxL
	var end: PxL
	var mode: SelectionMode
	var preview: BitSet?

	var didDrag: Bool { start.xy != end.xy }
}

struct LineSession: Equatable {
	enum Phase: Equatable {
		case pending
		case gesture(committable: Bool)
	}

	var start: PxL
	var end: PxL
	var phase: Phase
}

extension EditorState {

	mutating func cancelSessions() {
		selectionSession = nil
		lineSession = nil
	}

	mutating func toggleSelection() {
		selection.toggle()
	}

	mutating func invertSelection(size: FilmSize) {
		selection.invert(size: size)
	}

	mutating func resetTransientInteractions() {
		selection = .none
		cancelSessions()
	}

	mutating func beginSelection(at point: PxL, mode: SelectionMode) {
		guard selectionSession == nil else { return }
		selectionSession = SelectionSession(start: point.xy, end: point.xy, mode: mode)
	}

	mutating func updateSelection(to point: PxL, size: FilmSize) {
		guard var session = selectionSession, session.end != point.xy else { return }
		session.end = point.xy
		session.preview = session.didDrag ? mask(for: session, size: size) : nil
		selectionSession = session
	}

	var selectionPreview: BitSet? {
		selectionSession?.preview ?? selection.mask
	}

	mutating func endSelection() {
		guard let session = selectionSession else { return }
		if session.didDrag, let preview = session.preview {
			selection = Selection(preview)
		} else if session.mode == .replace {
			selection.active = false
		}
		selectionSession = nil
	}

	private func mask(for session: SelectionSession, size: FilmSize) -> BitSet {
		let rectangle = BitSet.rectangle(size: size, from: session.start, to: session.end)
		return switch session.mode {
		case .replace: rectangle
		case .union: selection.mask?.union(rectangle) ?? rectangle
		case .subtract: (selection.mask ?? BitSet(count: size.count, filled: true))
			.subtracting(rectangle)
		}
	}

	mutating func moveSelection(dx: Int = 0, dy: Int = 0, size: FilmSize) {
		selection.move(size: size, dx: dx, dy: dy)
	}

	mutating func beginLineGesture(at point: PxL) {
		let point = PxL(x: point.x, y: point.y, z: layer)
		if let session = lineSession, session.phase == .pending {
			lineSession = LineSession(start: session.start, end: point, phase: .gesture(committable: true))
		} else if lineSession == nil {
			lineSession = LineSession(start: point, end: point, phase: .gesture(committable: false))
		}
	}

	mutating func updateLine(to point: PxL, snapped: Bool) {
		guard var session = lineSession else { return }
		let point = PxL(x: point.x, y: point.y, z: session.start.z)
		session.end = snapped ? session.start.snappedEndpoint(to: point) : point
		if case let .gesture(committable) = session.phase {
			session.phase = .gesture(committable: committable || point.xy != session.start.xy)
		}
		lineSession = session
	}

	mutating func hoverLine(to point: PxL, snapped: Bool) {
		guard lineSession?.phase == .pending else { return }
		updateLine(to: point, snapped: snapped)
	}

	mutating func endLineGesture() -> (PxL, PxL)? {
		guard let session = lineSession, case let .gesture(committable) = session.phase else {
			return nil
		}
		guard committable else {
			lineSession = LineSession(start: session.start, end: session.end, phase: .pending)
			return nil
		}
		lineSession = nil
		return (session.start, session.end)
	}

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

	var ditherColor: Px { dither ? secondaryColor : primaryColor }

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
	case pencil, eraser, bucket, replace, eyedropper, selection, line
}

extension Tool {

	var actionName: String {
		switch self {
		case .pencil: "Pencil"
		case .eraser: "Erase"
		case .bucket: "Bucket"
		case .replace: "Replace"
		case .eyedropper: "Pick color"
		case .selection: "Select"
		case .line: "Line"
		}
	}

	var systemImage: String {
		switch self {
		case .pencil: "pencil"
		case .eraser: "eraser"
		case .bucket: "paint.bucket.classic"
		case .replace: "rectangle.2.swap"
		case .eyedropper: "eyedropper"
		case .selection: "rectangle.dashed"
		case .line: "line.diagonal"
		}
	}

	var shortcutCharacter: Character {
		switch self {
		case .pencil: "P"
		case .eraser: "E"
		case .bucket: "B"
		case .replace: "R"
		case .eyedropper: "I"
		case .selection: "S"
		case .line: "L"
		}
	}
}

extension EditorState {

	var dialogPresented: Bool {
		colorDialogPresented || sizeDialogPresented || shaderDialogPresented
	}
}
