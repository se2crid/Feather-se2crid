import SwiftUI
import NimbleViews
import UIKit

struct AppearanceCustomColorCellView: View {
	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = "#B496DC"
	@State private var customColor: Color = Color(hex: "#B496DC")
	
	var body: some View {
		HStack(spacing: 12) {
			NBTitleWithSubtitleView(title: .localized("Custom Color"), subtitle: .localized("Pick any tint color"))
			Spacer()
			ColorPicker("", selection: $customColor, supportsOpacity: false)
				.labelsHidden()
				.frame(maxWidth: 140)
			Circle()
				.fill(customColor)
				.frame(width: 22, height: 22)
		}
		.padding(.horizontal)
		.onAppear { customColor = Color(hex: selectedColorHex) }
		.onChange(of: customColor) { value in
			selectedColorHex = value.toHex()
			UIApplication.topViewController()?.view.window?.tintColor = UIColor(value)
		}
	}
}

private extension Color {
	init(hex: String) {
		let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		var int: UInt64 = 0
		Scanner(string: hexString).scanHexInt64(&int)
		let r, g, b: UInt64
		switch hexString.count {
		case 6:
			(r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
		default:
			(r, g, b) = (180, 150, 220)
		}
		self = Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
	}
	
	func toHex() -> String {
		let ui = UIColor(self)
		var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
		let ri = Int(r * 255), gi = Int(g * 255), bi = Int(b * 255)
		return String(format: "#%02X%02X%02X", ri, gi, bi)
	}
}
