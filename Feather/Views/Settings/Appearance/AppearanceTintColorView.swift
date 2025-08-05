//
//  AppearanceTintColorView.swift
//  Feather
//
//  Created by samara on 14.06.2025.
//

import SwiftUI

// MARK: - View
struct AppearanceTintColorView: View {
	@AppStorage("Feather.userTintColor") private var selectedColorHex: String = "#B496DC"
	@State private var customColor: Color = Color(hex: "#B496DC")
	private let tintOptions: [(name: String, hex: String)] = [
		("Default", 		"#B496DC"),
		("Classic", 		"#848ef9"),
		("Berry",   		"#ff7a83"),
		("Cool Blue", 		"#4161F1"),
		("Fuchsia", 		"#FF00FF"),
		("Protokolle", 		"#4CD964"),
		("Aidoku", 			"#FF2D55"),
		("Clock", 			"#FF9500"),
		("Peculiar", 		"#4860e8"),
		("Very Peculiar", 	"#5394F7"),
		("Emily",			"#e18aab")
	]
	
	// MARK: Body
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			LazyHGrid(rows: [GridItem(.fixed(100))], spacing: 12) {
				ForEach(tintOptions, id: \.hex) { option in
					let color = Color(hex: option.hex)
					VStack(spacing: 8) {
						Circle()
							.fill(color)
							.frame(width: 30, height: 30)
							.overlay(
								Circle()
									.strokeBorder(Color.black.opacity(0.3), lineWidth: 2)
							)
						Text(option.name)
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					.frame(width: 120, height: 100)
					.background(Color(uiColor: .secondarySystemGroupedBackground))
					.clipShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 10.5, style: .continuous)
							.strokeBorder(selectedColorHex == option.hex ? color : .clear, lineWidth: 2)
					)
					.onTapGesture { selectedColorHex = option.hex }
					.accessibilityLabel(Text(option.name))
				}
				Button(action: { selectedColorHex = customColor.toHex() }) {
					VStack(spacing: 8) {
						ColorPicker("", selection: $customColor, supportsOpacity: false)
							.labelsHidden()
							.frame(width: 30, height: 30)
							.clipShape(Circle())
							.overlay(
								Circle()
									.strokeBorder(Color.black.opacity(0.3), lineWidth: 2)
							)
						Text("Custom")
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
				}
				.buttonStyle(.plain)
				.frame(width: 120, height: 100)
				.background(Color(uiColor: .secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 10.5, style: .continuous)
						.strokeBorder(selectedColorHex == customColor.toHex() ? customColor : .clear, lineWidth: 2)
				)
			}
		}
		.onAppear { customColor = Color(hex: selectedColorHex) }
		.onChange(of: customColor) { value in
			let hex = value.toHex()
			selectedColorHex = hex
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

