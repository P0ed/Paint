import SwiftUI

extension EditorView {

	private var dispatch: (@escaping () -> Void) -> Void {
		{ f in DispatchQueue.main.async(execute: f) }
	}

	var keyboardController: (KeyPress) -> KeyPress.Result {
		{ keys in
			let modifiers = keys.modifiers
			let chars = keys.characters

			// Escape drops the gesture in flight; the committed selection survives it.
			// Deselect lives in `MenuCommands`; the main menu claims it first.
			if keys.key == .escape {
				guard state.selectionSession != nil || state.lineSession != nil else {
					return .ignored
				}
				state.cancelSessions()
				return .handled
			}

			func numAction(_ num: Int) {
				let idx = num + (modifiers.contains(.shift) ? 8 : 0)
				if modifiers.contains(.command) {
					palette = [Palette].builtin[idx & 0x7]
				} else if modifiers.contains(.control) {
					palette[idx] = state.primaryColor
				} else {
					state.primaryColor = palette[idx]
				}
			}

			switch chars {
			case "1", "!": numAction(0)
			case "2", "@": numAction(1)
			case "3", "#": numAction(2)
			case "4", "$": numAction(3)
			case "5", "%": numAction(4)
			case "6", "^": numAction(5)
			case "7", "&": numAction(6)
			case "8", "*": numAction(7)

			default:
				switch keys.key.character {
				case "\u{9}": state.nextLayer()
				case "\u{19}": state.prevLayer()
				case KeyEquivalent.leftArrow.character: dispatch { operations.move(dx: -1) }
				case KeyEquivalent.downArrow.character: dispatch { operations.move(dy: 1) }
				case KeyEquivalent.upArrow.character: dispatch { operations.move(dy: -1) }
				case KeyEquivalent.rightArrow.character: dispatch { operations.move(dx: 1) }
				default: return .ignored
				}
			}
			return .handled
		}
	}
}
