import SwiftUI

struct SizeDialog: View {
	var action: String = "Resize"
	var size: FilmSize
	var confirm: (Int, Int) -> Void

	@State var width: String = ""
	@State var height: String = ""

	private var w: Int? { width.isEmpty ? size.width : Int(width) }
	private var h: Int? { height.isEmpty ? size.height : Int(height) }

	private var isValid: Bool {
		guard let w, let h else { return false }
		return w > 0 && h > 0 && w * h <= FilmSize.max.count
	}

	var body: some View {
		Dialog(
			action: action,
			isValid: isValid,
			confirm: { if let w, let h { confirm(w, h) } }
		) {
			HStack {
				TextField("\(size.width)", text: $width)
					.frame(width: 64.0)
					.multilineTextAlignment(.trailing)

				Text("x")

				TextField("\(size.height)", text: $height)
					.frame(width: 64.0)
					.multilineTextAlignment(.trailing)
			}
		}
	}
}
