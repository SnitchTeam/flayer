import Foundation

struct EQBand: Codable, Identifiable {
    var id: Int
    let type: FilterType
    let frequency: Double
    let gain: Double
    let q: Double

    enum FilterType: String, Codable {
        case peak = "PK"
        case lowShelf = "LSC"
        case highShelf = "HSC"
    }
}

struct HeadphonePreset: Identifiable {
    let id: String
    let name: String
    let brand: String
    let type: HeadphoneType
    let preamp: Double
    let bands: [EQBand]

    enum HeadphoneType: String {
        case openBack = "open-back"
        case closedBack = "closed-back"
        case wireless = "wireless"
        case iem = "iem"

        var displayName: String {
            switch self {
            case .openBack: return Lang.openBack
            case .closedBack: return Lang.closedBack
            case .wireless: return Lang.wireless
            case .iem: return Lang.iem
            }
        }
    }
}

// MARK: - oratory1990-style EQ presets (Harman target approximations)

enum HeadphonePresetDatabase {

    static let all: [HeadphonePreset] = [
        // ── AKG ──
        HeadphonePreset(id: "akg-k371", name: "K371", brand: "AKG", type: .closedBack, preamp: -3.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1100, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "akg-k701", name: "K701", brand: "AKG", type: .openBack, preamp: -6.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +6.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.5, q: 0.71),
        ]),
        HeadphonePreset(id: "akg-k712", name: "K712 Pro", brand: "AKG", type: .openBack, preamp: -6.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3100, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5300, gain: -2.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 8500, gain: -2.0, q: 0.71),
        ]),

        HeadphonePreset(id: "akg-k361", name: "K361", brand: "AKG", type: .closedBack, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "akg-k553", name: "K553 MKII", brand: "AKG", type: .closedBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "akg-k240", name: "K240 Studio", brand: "AKG", type: .openBack, preamp: -6.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.5, q: 0.71),
        ]),

        // ── Apple ──
        HeadphonePreset(id: "apple-airpods-max", name: "AirPods Max", brand: "Apple", type: .wireless, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 750, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 2200, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5000, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: +1.5, q: 3.5),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "apple-airpods-pro2", name: "AirPods Pro 2", brand: "Apple", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 800, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +2.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),

        HeadphonePreset(id: "apple-airpods-pro", name: "AirPods Pro (1st Gen)", brand: "Apple", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 900, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2800, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "apple-airpods-4", name: "AirPods 4", brand: "Apple", type: .iem, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1000, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2600, gain: +2.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +0.5, q: 0.71),
        ]),

        // ── Audeze ──
        HeadphonePreset(id: "audeze-lcd2", name: "LCD-2 (2021)", brand: "Audeze", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +4.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: +2.0, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "audeze-lcd-x", name: "LCD-X (2021)", brand: "Audeze", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.5),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: +3.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),

        HeadphonePreset(id: "audeze-lcd3", name: "LCD-3", brand: "Audeze", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +3.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: +2.5, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "audeze-lcd4", name: "LCD-4", brand: "Audeze", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +3.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "audeze-maxwell", name: "Maxwell", brand: "Audeze", type: .wireless, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "audeze-mobius", name: "Mobius", brand: "Audeze", type: .wireless, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +3.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),

        // ── Audio-Technica ──
        HeadphonePreset(id: "at-m50x", name: "ATH-M50x", brand: "Audio-Technica", type: .closedBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 300, gain: +1.5, q: 1.0),
            EQBand(id: 2, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 4500, gain: -3.0, q: 3.5),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: +3.0, q: 3.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -2.5, q: 0.71),
        ]),
        HeadphonePreset(id: "at-msr7b", name: "ATH-MSR7b", brand: "Audio-Technica", type: .closedBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -3.0, q: 3.5),
            EQBand(id: 4, type: .peak, frequency: 7800, gain: +2.0, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "at-m40x", name: "ATH-M40x", brand: "Audio-Technica", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "at-m70x", name: "ATH-M70x", brand: "Audio-Technica", type: .closedBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 4800, gain: -3.5, q: 3.5),
            EQBand(id: 4, type: .peak, frequency: 7000, gain: +2.5, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "at-r70x", name: "ATH-R70x", brand: "Audio-Technica", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "at-ad700x", name: "ATH-AD700X", brand: "Audio-Technica", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3800, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "at-ad900x", name: "ATH-AD900X", brand: "Audio-Technica", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: +1.5, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 9500, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "at-awas", name: "ATH-AWAS", brand: "Audio-Technica", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "at-wp900", name: "ATH-WP900", brand: "Audio-Technica", type: .closedBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.5),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: +1.5, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -1.5, q: 0.71),
        ]),

        // ── Beyerdynamic ──
        HeadphonePreset(id: "beyer-dt770-80", name: "DT 770 Pro (80Ω)", brand: "Beyerdynamic", type: .closedBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2200, gain: -2.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 5000, gain: -4.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 6300, gain: +2.5, q: 4.0),
            EQBand(id: 4, type: .peak, frequency: 8500, gain: -5.5, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -3.0, q: 0.71),
        ]),
        HeadphonePreset(id: "beyer-dt880", name: "DT 880 (250Ω)", brand: "Beyerdynamic", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 5500, gain: -3.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 8200, gain: -5.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: -2.5, q: 0.71),
        ]),
        HeadphonePreset(id: "beyer-dt990", name: "DT 990 Pro", brand: "Beyerdynamic", type: .openBack, preamp: -7.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2500, gain: -2.0, q: 2.5),
            EQBand(id: 2, type: .peak, frequency: 5500, gain: -3.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 8200, gain: -7.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: -4.0, q: 0.71),
        ]),
        HeadphonePreset(id: "beyer-dt1990", name: "DT 1990 Pro", brand: "Beyerdynamic", type: .openBack, preamp: -6.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 4500, gain: -2.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: +2.5, q: 4.0),
            EQBand(id: 4, type: .peak, frequency: 8200, gain: -6.0, q: 3.5),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -3.0, q: 0.71),
        ]),

        HeadphonePreset(id: "beyer-dt700prox", name: "DT 700 Pro X", brand: "Beyerdynamic", type: .closedBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 4200, gain: -2.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 6500, gain: +2.0, q: 4.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "beyer-dt900prox", name: "DT 900 Pro X", brand: "Beyerdynamic", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2200, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 4800, gain: -2.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 8000, gain: -4.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "beyer-dt770-250", name: "DT 770 Pro (250Ω)", brand: "Beyerdynamic", type: .closedBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2200, gain: -2.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 5000, gain: -3.5, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 6300, gain: +2.0, q: 4.0),
            EQBand(id: 4, type: .peak, frequency: 8500, gain: -5.5, q: 4.0),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -3.0, q: 0.71),
        ]),
        HeadphonePreset(id: "beyer-dt1770", name: "DT 1770 Pro", brand: "Beyerdynamic", type: .closedBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 4500, gain: -3.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 6000, gain: +2.0, q: 4.0),
            EQBand(id: 4, type: .peak, frequency: 8200, gain: -5.0, q: 3.5),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: -2.5, q: 0.71),
        ]),

        // ── Bose ──
        HeadphonePreset(id: "bose-qc45", name: "QuietComfort 45", brand: "Bose", type: .wireless, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 700, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2800, gain: +3.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "bose-700", name: "Headphones 700", brand: "Bose", type: .wireless, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 800, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +3.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),

        HeadphonePreset(id: "bose-qc-ultra", name: "QuietComfort Ultra", brand: "Bose", type: .wireless, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +1.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 800, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.5, q: 0.71),
        ]),

        // ── Dan Clark Audio ──
        HeadphonePreset(id: "dca-aeon2-closed", name: "Aeon 2 Closed", brand: "Dan Clark Audio", type: .closedBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "dca-aeon2-open", name: "Aeon 2 Open", brand: "Dan Clark Audio", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "dca-stealth", name: "Stealth", brand: "Dan Clark Audio", type: .closedBack, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "dca-ether2", name: "Ether 2", brand: "Dan Clark Audio", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),

        // ── Denon ──
        HeadphonePreset(id: "denon-d9200", name: "AH-D9200", brand: "Denon", type: .closedBack, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "denon-d5200", name: "AH-D5200", brand: "Denon", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),

        // ── Focal ──
        HeadphonePreset(id: "focal-clear", name: "Clear", brand: "Focal", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "focal-utopia", name: "Utopia", brand: "Focal", type: .openBack, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9500, gain: -1.0, q: 0.71),
        ]),

        HeadphonePreset(id: "focal-celestee", name: "Celestee", brand: "Focal", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "focal-elegia", name: "Elegia", brand: "Focal", type: .closedBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +3.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -3.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "focal-elex", name: "Elex", brand: "Focal", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "focal-stellia", name: "Stellia", brand: "Focal", type: .closedBack, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9500, gain: -0.5, q: 0.71),
        ]),
        HeadphonePreset(id: "focal-bathys", name: "Bathys", brand: "Focal", type: .wireless, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "focal-radiance", name: "Radiance", brand: "Focal", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),

        // ── Grado ──
        HeadphonePreset(id: "grado-sr80x", name: "SR80x", brand: "Grado", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -2.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "grado-sr325x", name: "SR325x", brand: "Grado", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -2.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3800, gain: +1.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "grado-hemp", name: "Hemp", brand: "Grado", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),

        // ── HiFiMAN ──
        HeadphonePreset(id: "hifiman-he400se", name: "HE400SE", brand: "HiFiMAN", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 8500, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "hifiman-sundara", name: "Sundara", brand: "HiFiMAN", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +1.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 4800, gain: -2.5, q: 4.0),
            EQBand(id: 4, type: .highShelf, frequency: 8000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "hifiman-ananda", name: "Ananda", brand: "HiFiMAN", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "hifiman-edition-xs", name: "Edition XS", brand: "HiFiMAN", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),

        HeadphonePreset(id: "hifiman-arya", name: "Arya", brand: "HiFiMAN", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "hifiman-deva-pro", name: "Deva Pro", brand: "HiFiMAN", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 8500, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "hifiman-he6se", name: "HE6SE V2", brand: "HiFiMAN", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +3.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.0, q: 0.71),
        ]),

        // ── Koss ──
        HeadphonePreset(id: "koss-portapro", name: "Porta Pro", brand: "Koss", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: +1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +3.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "koss-kph40", name: "KPH40", brand: "Koss", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "koss-ksc75", name: "KSC75", brand: "Koss", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3800, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),

        // ── Meze ──
        HeadphonePreset(id: "meze-99classics", name: "99 Classics", brand: "Meze", type: .closedBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 400, gain: +1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "meze-109pro", name: "109 Pro", brand: "Meze", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "meze-empyrean", name: "Empyrean", brand: "Meze", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +3.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "meze-elite", name: "Elite", brand: "Meze", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),

        // ── Moondrop ──
        HeadphonePreset(id: "moondrop-blessing2", name: "Blessing 2", brand: "Moondrop", type: .iem, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -0.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3800, gain: -1.5, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: +1.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "moondrop-aria", name: "Aria", brand: "Moondrop", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),

        HeadphonePreset(id: "moondrop-kato", name: "Kato", brand: "Moondrop", type: .iem, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -0.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: -1.0, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: +1.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "moondrop-variations", name: "Variations", brand: "Moondrop", type: .iem, preamp: -3.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -0.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: -1.5, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: +1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -0.5, q: 0.71),
        ]),
        HeadphonePreset(id: "moondrop-chu", name: "Chu", brand: "Moondrop", type: .iem, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +0.5, q: 0.71),
        ]),
        HeadphonePreset(id: "moondrop-starfield", name: "Starfield", brand: "Moondrop", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),

        // ── Samsung ──
        HeadphonePreset(id: "samsung-buds2pro", name: "Galaxy Buds2 Pro", brand: "Samsung", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 900, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2800, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "samsung-buds-fe", name: "Galaxy Buds FE", brand: "Samsung", type: .iem, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1000, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),

        // ── Sennheiser ──
        HeadphonePreset(id: "senn-hd560s", name: "HD 560S", brand: "Sennheiser", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-hd600", name: "HD 600", brand: "Sennheiser", type: .openBack, preamp: -6.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: -2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: +3.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 8500, gain: -3.5, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-hd650", name: "HD 650 / HD 6XX", brand: "Sennheiser", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: -3.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: +3.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 8000, gain: -2.5, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-hd800s", name: "HD 800 S", brand: "Sennheiser", type: .openBack, preamp: -6.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 5500, gain: -4.5, q: 5.0),
            EQBand(id: 3, type: .peak, frequency: 6300, gain: +3.5, q: 4.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -3.0, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-ie300", name: "IE 300", brand: "Sennheiser", type: .iem, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: +1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +3.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),

        HeadphonePreset(id: "senn-hd660s", name: "HD 660S", brand: "Sennheiser", type: .openBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3300, gain: -2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: +2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 8500, gain: -2.5, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-hd660s2", name: "HD 660S2", brand: "Sennheiser", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 8500, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-ie600", name: "IE 600", brand: "Sennheiser", type: .iem, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -1.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: +1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-ie900", name: "IE 900", brand: "Sennheiser", type: .iem, preamp: -3.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -0.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: +0.5, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +0.5, q: 0.71),
        ]),
        HeadphonePreset(id: "senn-momentum4", name: "Momentum 4", brand: "Sennheiser", type: .wireless, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +1.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 800, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),

        // ── Shure ──
        HeadphonePreset(id: "shure-se215", name: "SE215", brand: "Shure", type: .iem, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1200, gain: +1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3000, gain: +3.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "shure-se535", name: "SE535", brand: "Shure", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "shure-srh840a", name: "SRH840A", brand: "Shure", type: .closedBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "shure-srh1540", name: "SRH1540", brand: "Shure", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1400, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
        HeadphonePreset(id: "shure-aonic50", name: "Aonic 50 Gen 2", brand: "Shure", type: .wireless, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 800, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: +1.0, q: 0.71),
        ]),

        // ── Sony ──
        HeadphonePreset(id: "sony-mdr7506", name: "MDR-7506", brand: "Sony", type: .closedBack, preamp: -5.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 2000, gain: -2.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 4500, gain: -3.5, q: 3.0),
            EQBand(id: 3, type: .peak, frequency: 7000, gain: +2.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "sony-xm4", name: "WH-1000XM4", brand: "Sony", type: .wireless, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 400, gain: +1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2000, gain: -2.5, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 4500, gain: +2.0, q: 3.0),
            EQBand(id: 4, type: .peak, frequency: 7500, gain: -3.5, q: 3.5),
            EQBand(id: 5, type: .highShelf, frequency: 10000, gain: +2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "sony-xm5", name: "WH-1000XM5", brand: "Sony", type: .wireless, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -1.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 500, gain: +1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2200, gain: +2.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5000, gain: -2.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),

        HeadphonePreset(id: "sony-mdr-z1r", name: "MDR-Z1R", brand: "Sony", type: .closedBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "sony-ier-z1r", name: "IER-Z1R", brand: "Sony", type: .iem, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: -1.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1300, gain: +1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5800, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +0.5, q: 0.71),
        ]),
        HeadphonePreset(id: "sony-wf-xm5", name: "WF-1000XM5", brand: "Sony", type: .iem, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 100, gain: +1.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 800, gain: -1.0, q: 1.5),
            EQBand(id: 2, type: .peak, frequency: 2500, gain: +2.0, q: 2.0),
            EQBand(id: 3, type: .peak, frequency: 5200, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 10000, gain: +1.5, q: 0.71),
        ]),

        // ── STAX ──
        HeadphonePreset(id: "stax-l300", name: "SR-L300", brand: "STAX", type: .openBack, preamp: -5.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +5.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1800, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -2.0, q: 0.71),
        ]),
        HeadphonePreset(id: "stax-l700", name: "SR-L700 MKII", brand: "STAX", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +4.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1700, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),

        // ── ZMF ──
        HeadphonePreset(id: "zmf-auteur", name: "Auteur", brand: "ZMF", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "zmf-aeolus", name: "Aeolus", brand: "ZMF", type: .openBack, preamp: -4.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -2.0, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "zmf-atrium", name: "Atrium", brand: "ZMF", type: .openBack, preamp: -4.0, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +3.0, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1600, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3500, gain: +1.5, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.0),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.5, q: 0.71),
        ]),
        HeadphonePreset(id: "zmf-verite", name: "Vérité", brand: "ZMF", type: .openBack, preamp: -3.5, bands: [
            EQBand(id: 0, type: .lowShelf, frequency: 105, gain: +2.5, q: 0.71),
            EQBand(id: 1, type: .peak, frequency: 1500, gain: -1.0, q: 2.0),
            EQBand(id: 2, type: .peak, frequency: 3200, gain: +2.0, q: 2.5),
            EQBand(id: 3, type: .peak, frequency: 5500, gain: -1.5, q: 3.5),
            EQBand(id: 4, type: .highShelf, frequency: 9000, gain: -1.0, q: 0.71),
        ]),
    ]

    static func find(id: String) -> HeadphonePreset? {
        all.first { $0.id == id }
    }
}
