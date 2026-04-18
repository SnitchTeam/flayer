import WidgetKit
import SwiftUI

struct FlaYerPlayerWidget: Widget {
    let kind = "FlaYerPlayer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlayerTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Player")
        .description("Music player controls and library")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PlayerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

@main
struct FlaYerWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlaYerPlayerWidget()
    }
}
