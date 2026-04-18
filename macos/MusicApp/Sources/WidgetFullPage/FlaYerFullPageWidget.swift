import WidgetKit
import SwiftUI

struct FlaYerFullPageWidget: Widget {
    let kind = "FlaYerFullPage"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FullPageTimelineProvider()) { entry in
            FullPageWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Player")
        .description("Full music player experience")
        .supportedFamilies([.systemExtraLarge])
    }
}

@main
struct FlaYerFullPageBundle: WidgetBundle {
    var body: some Widget {
        FlaYerFullPageWidget()
    }
}
