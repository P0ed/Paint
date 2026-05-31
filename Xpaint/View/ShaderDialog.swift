import SwiftUI

struct ShaderDialog: View {
	@Binding var shader: Shader
	@State private var text: String = ""

	var body: some View {
		Dialog(
			action: "Set",
			confirm: { shader.function = text.isEmpty ? Shader.default.function : text }
		) {
			TextEditor(text: $text).onAppear {
				text = shader.function
			}
			.frame(minHeight: 128.0)
		}
	}
}
