import SwiftUI
import SetaMacCore

struct SetZonesLegendHeader: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        GlassPanel(cornerRadius: 10, compact: true) {
            MixDockTabButton(shortcut: "z", title: "zones", count: store.filter.moments.count, isActive: false) {
                store.momentsLegendOpen = true
            }
        }
    }
}

struct SetZonesLegend: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    MixDockTabButton(
                        shortcut: "z",
                        title: "zones",
                        count: store.filter.moments.count,
                        isActive: store.momentsLegendOpen
                    ) {
                        store.momentsLegendOpen.toggle()
                    }
                    Spacer()
                    SetaResetButton(disabled: store.filter.moments.isEmpty) {
                        store.clearMomentFilter()
                    }
                }
                if !store.filter.moments.isEmpty {
                    Text("Showing selected zones")
                        .font(.system(size: 9))
                        .foregroundStyle(SetaTheme.muted)
                }
                ForEach(SetMoments.sections, id: \.label) { section in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.label.uppercased())
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(SetaTheme.muted)
                            .padding(.horizontal, 4)
                            .padding(.top, section.label == SetMoments.sections.first?.label ? 0 : 8)
                        ForEach(section.ids, id: \.self) { momentID in
                            if let moment = SetMoments.moment(id: momentID) {
                                Button {
                                    store.toggleMoment(momentID)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("☁")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color(hex: moment.colorHex))
                                        Text(moment.label)
                                            .font(.system(size: 10))
                                            .foregroundStyle(store.filter.moments.contains(momentID) ? SetaTheme.accent : SetaTheme.text)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(store.filter.moments.contains(momentID) ? SetaTheme.accentSoft : Color.clear)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                store.filter.moments.contains(momentID)
                                                    ? SetaTheme.accent.opacity(0.28)
                                                    : Color.clear
                                            )
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .opacity(
                                    store.filter.moments.isEmpty || store.filter.moments.contains(momentID) ? 1 : 0.34
                                )
                            }
                        }
                    }
                    if section.label != SetMoments.sections.last?.label {
                        Divider().opacity(0.85)
                    }
                }
            }
        }
        .frame(width: SetaTheme.legendWidth)
    }
}

struct CamelotLegendHeader: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        GlassPanel(cornerRadius: 10, compact: true) {
            MixDockTabButton(shortcut: "k", title: "keys", count: store.filter.keys.count, isActive: false) {
                store.camelotLegendOpen = true
            }
        }
    }
}

struct CamelotLegend: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    MixDockTabButton(
                        shortcut: "k",
                        title: "keys",
                        count: store.filter.keys.count,
                        isActive: store.camelotLegendOpen
                    ) {
                        store.camelotLegendOpen.toggle()
                    }
                    Spacer()
                    SetaResetButton(disabled: store.filter.keys.isEmpty) {
                        store.clearKeyFilter()
                    }
                }
                if !store.filter.keys.isEmpty {
                    Text("Showing selected keys")
                        .font(.system(size: 9))
                        .foregroundStyle(SetaTheme.muted)
                }
                CamelotWheelView(activeKeys: store.filter.keys, filtering: !store.filter.keys.isEmpty) { key in
                    store.toggleKey(key)
                }
            }
        }
        .frame(width: SetaTheme.legendWidth)
    }
}
