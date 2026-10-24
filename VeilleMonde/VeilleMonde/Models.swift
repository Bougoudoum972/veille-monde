import Foundation

enum Category: String, CaseIterable, Identifiable {
    case geo, eco, transport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .geo: "Géopolitique"
        case .eco: "Économie"
        case .transport: "Transport"
        }
    }

    var icon: String {
        switch self {
        case .geo: "globe.europe.africa.fill"
        case .eco: "chart.line.uptrend.xyaxis"
        case .transport: "box.truck.fill"
        }
    }

    var topics: [Topic] { Topic.allCases.filter { $0.category == self } }
}

/// Sous-thème d'un onglet, affiché sous forme de pastilles en haut de la liste.
enum Topic: String, CaseIterable, Identifiable {
    case world, africa, defense
    case france, global
    case air, road, sea, logistics

    var id: String { rawValue }

    var category: Category {
        switch self {
        case .world, .africa, .defense: .geo
        case .france, .global: .eco
        case .air, .road, .sea, .logistics: .transport
        }
    }

    var title: String {
        switch self {
        case .world: "International"
        case .africa: "Afrique"
        case .defense: "Défense"
        case .france: "France"
        case .global: "Monde"
        case .air: "Aérien"
        case .road: "Routier"
        case .sea: "Maritime"
        case .logistics: "Logistique"
        }
    }

    var icon: String {
        switch self {
        case .world: "globe"
        case .africa: "globe.europe.africa"
        case .defense: "shield.lefthalf.filled"
        case .france: "building.columns"
        case .global: "dollarsign.arrow.circlepath"
        case .air: "airplane"
        case .road: "truck.box.fill"
        case .sea: "ferry.fill"
        case .logistics: "shippingbox.fill"
        }
    }
}

struct Feed: Identifiable, Hashable {
    let source: String
    let topic: Topic
    let url: URL

    var id: String { url.absoluteString }
    var category: Category { topic.category }

    init(_ source: String, _ topic: Topic, _ url: String) {
        self.source = source
        self.topic = topic
        self.url = URL(string: url)!
    }
}

struct Article: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let link: URL
    let date: Date?
    let imageURL: URL?
    let source: String
    let topic: Topic

    var category: Category { topic.category }
}

extension Feed {
    /// Ajoute ou retire des sources ici.
    static let all: [Feed] = [
        // Géopolitique — international
        Feed("Le Monde", .world, "https://www.lemonde.fr/international/rss_full.xml"),
        Feed("Le Figaro", .world, "https://www.lefigaro.fr/rss/figaro_international.xml"),
        Feed("France 24", .world, "https://www.france24.com/fr/rss"),
        Feed("RFI", .world, "https://www.rfi.fr/fr/rss"),
        Feed("Courrier International", .world, "https://www.courrierinternational.com/feed/all/rss.xml"),
        Feed("Politico Europe", .world, "https://www.politico.eu/section/politics/feed/"),
        Feed("BBC World", .world, "https://feeds.bbci.co.uk/news/world/rss.xml"),
        Feed("The Guardian", .world, "https://www.theguardian.com/world/rss"),
        Feed("Al Jazeera", .world, "https://www.aljazeera.com/xml/rss/all.xml"),
        // Géopolitique — Afrique
        Feed("Le Monde Afrique", .africa, "https://www.lemonde.fr/afrique/rss_full.xml"),
        Feed("RFI Afrique", .africa, "https://www.rfi.fr/fr/afrique/rss"),
        Feed("France 24 Afrique", .africa, "https://www.france24.com/fr/afrique/rss"),
        Feed("Jeune Afrique", .africa, "https://www.jeuneafrique.com/feed/"),
        Feed("BBC Afrique", .africa, "https://www.bbc.com/afrique/index.xml"),
        Feed("Africanews", .africa, "https://fr.africanews.com/feed/rss"),
        Feed("The Africa Report", .africa, "https://www.theafricareport.com/feed/"),
        Feed("Financial Afrik", .africa, "https://www.financialafrik.com/feed/"),
        // Géopolitique — défense et conflits
        Feed("Revue Conflits", .defense, "https://www.revueconflits.com/feed/"),
        Feed("Politico Défense", .defense, "https://rss.politico.com/defense.xml"),
        // Économie — France
        Feed("Le Monde Éco", .france, "https://www.lemonde.fr/economie/rss_full.xml"),
        Feed("Le Figaro Éco", .france, "https://www.lefigaro.fr/rss/figaro_economie.xml"),
        Feed("La Tribune", .france, "https://www.latribune.fr/feed.xml"),
        // Économie — monde
        Feed("France 24 Éco", .global, "https://www.france24.com/fr/%C3%A9co-tech/rss"),
        Feed("BBC Business", .global, "https://feeds.bbci.co.uk/news/business/rss.xml"),
        Feed("The Guardian Business", .global, "https://www.theguardian.com/business/rss"),
        Feed("CNBC World", .global, "https://www.cnbc.com/id/100727362/device/rss/rss.html"),
        // Transport — aérien
        Feed("Air Journal", .air, "https://www.air-journal.fr/feed"),
        Feed("Aerobuzz", .air, "https://www.aerobuzz.fr/feed/"),
        Feed("Journal de l'Aviation", .air, "https://www.journal-aviation.com/rss"),
        Feed("Air Cargo News", .air, "https://www.aircargonews.net/feed/"),
        // Transport — routier
        Feed("Transport Info", .road, "https://www.transportinfo.fr/feed/"),
        Feed("L'Officiel des Transporteurs", .road, "https://www.wk-transport-logistique.fr/rss"),
        Feed("Flotauto", .road, "https://www.flotauto.com/rss"),
        Feed("Transport Topics", .road, "https://www.ttnews.com/rss.xml"),
        // Transport — maritime
        Feed("Ports et Corridors", .sea, "https://www.portsetcorridors.com/feed/"),
        Feed("gCaptain", .sea, "https://gcaptain.com/feed/"),
        Feed("Splash247", .sea, "https://splash247.com/feed/"),
        Feed("Seatrade Maritime", .sea, "https://www.seatrade-maritime.com/rss.xml"),
        Feed("Hellenic Shipping News", .sea, "https://www.hellenicshippingnews.com/feed/"),
        // Transport — logistique (multimodal)
        Feed("The Loadstar", .logistics, "https://theloadstar.com/feed/"),
    ]
}
