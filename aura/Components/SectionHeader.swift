import SwiftUI

// ============================================================
// MARK: - SECTION HEADER
// ============================================================

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }
}
