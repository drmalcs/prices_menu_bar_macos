import SwiftUI

struct ErrorLogView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            if store.priceService.errorLog.isEmpty {
                Text("No errors").foregroundStyle(.secondary).padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.priceService.errorLog.reversed()) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, style: .time)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(entry.message)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .font(.caption)
                        }
                    }
                    .padding(12)
                }
                Divider()
                Button("Clear log") {
                    store.priceService.errorLog.removeAll()
                }
                .padding(8)
            }
        }
    }
}
