import SwiftUI

struct ColorDialog: View {
	@Binding var color: Px

	@State var hexRGB: String = ""
	@State var hexA: String = ""

	private var px: Px {
		modifying(.clear, { px in
			let shex = Int(hexRGB, radix: 16) ?? 0xFFFFFF
			let hex = (shex & 0xFF << 8) | (shex & 0xFF) << 16 | (shex & 0xFF << 16) >> 16
			px = Px(rgb: UInt32(clamping: hex))
			px.alpha = UInt8(clamping: Int(hexA, radix: 16) ?? 0xFF)
		})
	}

	var body: some View {
		Dialog(
			action: "Set",
			confirm: { color = px }
		) {
			HStack {
				TextField("RRGGBB", text: $hexRGB)
					.frame(width: 64.0)
					.multilineTextAlignment(.trailing)
				Text("*")
				TextField("AA", text: $hexA)
					.frame(width: 32.0)
					.multilineTextAlignment(.trailing)
			}
		}
		.background(Color(cgColor: px.cg))
	}
}
