import Foundation

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var failedSources: [String] = []
    @Published private(set) var lastUpdate: Date?

    /// Recharge seulement si les données ont plus de 15 minutes.
    func refreshIfStale() async {
        if let lastUpdate, Date().timeIntervalSince(lastUpdate) < 15 * 60 { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Au premier chargement, chaque source s'affiche dès qu'elle arrive ;
        // ensuite, la liste n'est remplacée qu'une fois tout reçu, sans clignoter.
        let progressive = articles.isEmpty
        var all: [Article] = []
        var failed: [String] = []
        await withTaskGroup(of: (Feed, [Article]?).self) { group in
            for feed in Feed.all {
                group.addTask { (feed, await Self.load(feed)) }
            }
            for await (feed, items) in group {
                if let items { all += items } else { failed.append(feed.source) }
                if progressive, items != nil {
                    articles = Self.merged(all)
                    lastUpdate = Date()
                }
            }
        }

        articles = Self.merged(all)
        failedSources = failed.sorted()
        lastUpdate = Date()
    }

    private static func merged(_ items: [Article]) -> [Article] {
        var seen = Set<String>()
        return items
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    nonisolated private static func load(_ feed: Feed) async -> [Article]? {
        var request = URLRequest(url: feed.url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (iPhone) VeilleMonde/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode < 400 else { return nil }
        let items = RSSParser(feed: feed).parse(data)
        return items.isEmpty ? nil : Array(items.prefix(25))
    }
}
