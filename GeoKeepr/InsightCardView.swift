import SwiftUI

struct InsightCardView: View {
    let icon: Image
    let iconColor: Color
    let title: String
    let mainText: String
    let detailText: String

    var body: some View {
        HStack(spacing: 12) {
            icon
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mainText)
                    .font(.subheadline)
                    .bold()
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: iconColor.opacity(0.3), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}
