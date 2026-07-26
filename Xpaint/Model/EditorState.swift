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
	var selection: BitSet?
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
	/// The mask this drag would commit, rebuilt only when the drag reaches another pixel.
	var preview: BitSet?

	var didDrag: Bool { start.xy != end.xy }
}

struct LineSession: Equatable {
	enum Phase: Equatable {
		case pending
		/// An in-flight drag. `committable` once it has travelled far enough to be worth drawing.
		case gesture(committable: Bool)
	}

	var start: PxL
	var end: PxL
	var phase: Phase
}

extension EditorState {

	/// Drops any in-progress gesture, keeping the committed selection.
	mutating func cancelSessions() {
		selectionSession = nil
		lineSession = nil
	}

	mutating func clearSelection() {
		selection = nil
		selectionSession = nil
	}

	mutating func resetTransientInteractions() {
		selection = nil
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

	/// What the canvas draws: the drag in flight when there is one, otherwise the committed mask.
	var selectionPreview: BitSet? {
		selectionSession?.preview ?? selection
	}

	mutating func endSelection() {
		guard let session = selectionSession else { return }
		if session.didDrag {
			selection = session.preview
		} else if session.mode == .replace {
			selection = nil
		}
		selectionSession = nil
	}

	private func mask(for session: SelectionSession, size: FilmSize) -> BitSet {
		let rectangle = BitSet.rectangle(size: size, from: session.start, to: session.end)
		return switch session.mode {
		case .replace: rectangle
		case .union: selection?.union(rectangle) ?? rectangle
		// No selection means the whole layer, so subtracting leaves everything but the rectangle.
		case .subtract: (selection ?? BitSet(count: size.count, filled: true)).subtracting(rectangle)
		}
	}

	/// Slides the committed mask, if there is one, leaving the pixels under it alone.
	mutating func moveSelection(dx: Int = 0, dy: Int = 0, size: FilmSize) {
		selection = selection?.moved(size: size, dx: dx, dy: dy)
	}

	mutating func beginLineGesture(at point: PxL) {
		let point = PxL(x: point.x, y: point.y, z: layer)
		if let session = lineSession, session.phase == .pending {
			// Second click of a click-click line: it commits however short the drag is.
			lineSession = LineSession(start: session.start, end: point, phase: .gesture(committable: true))
		} else if lineSession == nil {
			lineSession = LineSession(start: point, end: point, phase: .gesture(committable: false))
		}
	}

	mutating func updateLine(to point: PxL, snapped: Bool) {
		guard var session = lineSession else { return }
		let point = PxL(x: point.x, y: point.y, z: session.start.z)
		session.end = snapped ? snappedEndpoint(from: session.start, to: point) : point
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
			// A click that went nowhere: arm the first point and wait for the second click.
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

	/// The colour every tool alternates with while dithering; `primaryColor` when dithering is off.
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
