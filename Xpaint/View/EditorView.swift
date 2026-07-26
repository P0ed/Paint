import SwiftUI
import UniformTypeIdentifiers

struct EditorView<ContentType: TypeProvider>: View {
	@UserDefault(default: .default) var shader: Shader
	@State var state: EditorState = .init()
	@Binding var palette: Palette
	@Binding var film: Film
	@Binding var global: Film

	@GestureState var magnifyGestureState: CGFloat?
	@FocusState private(set) var focused: Bool
	@Environment(\.undoManager) var undoManager

	var body: some View {
		NavigationSplitView(
			sidebar: { sidebar },
			detail: { canvas }
		)
		.toolbar { toolbar }
		.focusable()
		.focused($focused)
		.focusEffectDisabled()
		.focusedSceneValue(\.operations, operations)
		.onAppear { focused = true }
		.onKeyPress(action: keyboardController)
		.fileExporter(
			isPresented: $state.exporting,
			document: state.exportedFilm.map(Document<ContentType.ExportType>.init(film:)),
			contentType: ContentType.ExportType.type
		) { _ in
			state.exportedFilm = nil
		}
		.sheet(isPresented: $state.sizeDialogPresented) { sizeDialog }
		.sheet(isPresented: $state.colorDialogPresented) { colorDialog }
		.sheet(isPresented: $state.shaderDialogPresented) { shaderDialog }
	}

	var sizeDialog: some View {
		SizeDialog(size: film.size) { w, h in
			film.resize(width: w, height: h)
			state.resetTransientInteractions()
		}
	}

	var colorDialog: some View {
		ColorDialog(color: $state.primaryColor)
	}

	var shaderDialog: some View {
		ShaderDialog(shader: $shader)
	}

	var operations: Operations {
		Operations(
			state: $state,
			palette: $palette,
			shader: $shader,
			film: _film,
			global: _global
		)
	}

	private var canvas: some View {
		ScrollView([.horizontal, .vertical]) {
			GeometryReader { geo in
				Canvas { ctx, size in
					film.render(mask: state.visibleLayers, in: ctx, size: size)
					renderLinePreview(in: ctx)
					renderSelection(in: ctx)
				}
				.gesture(drawingController)
				.onContinuousHover { phase in
					if case let .active(location) = phase {
						hoverLine(at: location)
					}
				}
				.onChange(of: geo.frame(in: .scrollView)) { _, new in
					state.frame = new
				}
			}
			.frame(
				width: film.size.cg.width * state.magnification,
				height: film.size.cg.height * state.magnification
			)
		}
		.scrollPosition($state.scrollPosition)
		.gesture(magnificationController)
		.background { background }
	}

	private func renderLinePreview(in context: GraphicsContext) {
		guard let session = state.lineSession else { return }
		let selection = state.selection
		let scale = state.magnification
		let primary = state.primaryColor
		let secondary = state.ditherColor

		for point in rasterizedLine(from: session.start, to: session.end) {
			guard let index = film.size.index(at: point.xy), selection.allows(index) else { continue }
			let row = film.size.height - 1 - point.y
			let rect = CGRect(
				x: CGFloat(point.x) * scale,
				y: CGFloat(row) * scale,
				width: scale,
				height: scale
			)
			let color = point.isEven ? primary : secondary
			context.fill(
				Path(rect),
				with: .color(color.ui),
				style: FillStyle(eoFill: false, antialiased: false)
			)
		}
	}

	private func renderSelection(in context: GraphicsContext) {
		guard let selection = state.selectionPreview, !selection.isEmpty else { return }
		let scale = state.magnification
		var boundary = Path()

		func isSelected(x: Int, y: Int) -> Bool {
			film.size.index(at: PxL(x: x, y: y, z: 0)).map { selection[$0] } ?? false
		}

		for index in selection {
			let point = film.size.pxl(at: index)
			let left = CGFloat(point.x) * scale
			let right = left + scale
			let top = CGFloat(film.size.height - 1 - point.y) * scale
			let bottom = top + scale

			if !isSelected(x: point.x - 1, y: point.y) {
				boundary.move(to: CGPoint(x: left, y: top))
				boundary.addLine(to: CGPoint(x: left, y: bottom))
			}
			if !isSelected(x: point.x + 1, y: point.y) {
				boundary.move(to: CGPoint(x: right, y: top))
				boundary.addLine(to: CGPoint(x: right, y: bottom))
			}
			if !isSelected(x: point.x, y: point.y + 1) {
				boundary.move(to: CGPoint(x: left, y: top))
				boundary.addLine(to: CGPoint(x: right, y: top))
			}
			if !isSelected(x: point.x, y: point.y - 1) {
				boundary.move(to: CGPoint(x: left, y: bottom))
				boundary.addLine(to: CGPoint(x: right, y: bottom))
			}
		}

		context.stroke(boundary, with: .color(.black), lineWidth: 2)
		context.stroke(
			boundary,
			with: .color(.white),
			style: StrokeStyle(lineWidth: 1, dash: [4, 4])
		)
	}

	private var background: some View {
		GeometryReader { geo in
			Image(.background).resizable(resizingMode: .tile)
				.onChange(of: geo.size) { _, new in
					guard new.width != 0.0, new.height != 0.0 else { return }

					let old = state.size
					state.size = new
					if old == .zero {
						setScale(film.size.zoomToFit(state.size))
					}
				}
		}
	}

	func setScale(_ magnification: CGFloat) {
		state.setScale(magnification)
	}

	private var magnificationController: some Gesture {
		MagnifyGesture(minimumScaleDelta: 0)
			.updating($magnifyGestureState) { gesture, initial, _ in
				if initial == .none { initial = state.magnification }
				let initial = initial ?? state.magnification
				setScale(initial * gesture.magnification)
			}
	}
}
