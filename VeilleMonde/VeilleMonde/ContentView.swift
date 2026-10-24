import SafariServices
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NewsStore

    var body: some View {
        TabView {
            NewsListView(category: nil)
                .tabItem { Label("À la une", systemImage: "newspaper.fill") }
            ForEach(Category.allCases) { category in
                NewsListView(category: category)
                    .tabItem { Label(category.title, systemImage: category.icon) }
            }
        }
        .task { await store.refreshIfStale() }
    }
}

// MARK: - Liste d'articles

struct DaySection: Identifiable {
    let title: String
    var articles: [Article]
    var id: String { title }
}

struct NewsListView: View {
    let category: Category?

    @EnvironmentObject private var store: NewsStore
    @State private var search = ""
    @State private var topic: Topic?
    @State private var source: String?
    @State private var selected: Article?

    private var sources: [String] {
        Feed.all
            .filter { (category == nil || $0.category == category) && (topic == nil || $0.topic == topic) }
            .map(\.source)
    }

    private var filtered: [Article] {
        store.articles.filter { a in
            (category == nil || a.category == category)
                && (topic == nil || a.topic == topic)
                && (source == nil || a.source == source)
                && (search.isEmpty
                    || a.title.localizedCaseInsensitiveContains(search)
                    || a.summary.localizedCaseInsensitiveContains(search))
        }
    }

    /// Articles regroupés par jour : Aujourd'hui, Hier, puis la date.
    private var sections: [DaySection] {
        var result: [DaySection] = []
        for article in filtered {
            let title = Self.dayTitle(article.date)
            if result.last?.title == title {
                result[result.count - 1].articles.append(article)
            } else {
                result.append(DaySection(title: title, articles: [article]))
            }
        }
        return result
    }

    /// Le premier article avec photo s'affiche en grand, sauf pendant une recherche.
    private var heroID: String? {
        guard search.isEmpty else { return nil }
        return filtered.prefix(5).first { $0.imageURL != nil }?.id
    }

    var body: some View {
        NavigationStack {
            List {
                if category != nil || source != nil {
                    filterBar
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.articles) { article in
                            row(for: article)
                        }
                    } header: {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                }
                if !filtered.isEmpty { updateFooter }
            }
            .listStyle(.plain)
            .overlay { emptyState }
            .navigationTitle(category?.title ?? "À la une")
            .searchable(text: $search, prompt: "Pays, entreprise, sujet…")
            .refreshable { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { sourceMenu }
            }
            .onChange(of: topic) { _, _ in
                if let source, !sources.contains(source) { self.source = nil }
            }
            .sheet(item: $selected) { article in
                SafariView(url: article.link).ignoresSafeArea()
            }
        }
    }

    private func row(for article: Article) -> some View {
        Button { selected = article } label: {
            if article.id == heroID {
                HeroCard(article: article)
            } else {
                ArticleRow(article: article)
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(article.id == heroID ? .hidden : .automatic)
        .contextMenu {
            ShareLink(item: article.link) { Label("Partager", systemImage: "square.and.arrow.up") }
            Link(destination: article.link) { Label("Ouvrir dans Safari", systemImage: "safari") }
        }
    }

    // MARK: Filtres

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category {
                    Chip(title: "Tout", isOn: topic == nil, color: category.color) { topic = nil }
                    ForEach(category.topics) { t in
                        Chip(title: t.title, icon: t.icon, isOn: topic == t, color: category.color) { topic = t }
                    }
                }
                if let source {
                    Chip(title: source, icon: "xmark", isOn: true, color: .secondary) { self.source = nil }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var sourceMenu: some View {
        Menu {
            Picker("Source", selection: $source) {
                Text("Toutes les sources").tag(String?.none)
                ForEach(sources, id: \.self) { Text($0).tag(String?.some($0)) }
            }
        } label: {
            Image(systemName: source == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Choisir une source")
    }

    // MARK: États

    private var updateFooter: some View {
        VStack(spacing: 4) {
            if let lastUpdate = store.lastUpdate {
                Text("Mis à jour à \(lastUpdate.formatted(date: .omitted, time: .shortened)) · tirer pour actualiser")
            }
            if !store.failedSources.isEmpty {
                Text("Indisponible : \(store.failedSources.joined(separator: ", "))")
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder private var emptyState: some View {
        if filtered.isEmpty {
            if store.isLoading || store.lastUpdate == nil {
                ProgressView("Chargement des actualités…")
            } else if !search.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ContentUnavailableView(
                    "Aucun article",
                    systemImage: "newspaper",
                    description: Text("Tire vers le bas pour actualiser.")
                )
            }
        }
    }

    private static func dayTitle(_ date: Date?) -> String {
        guard let date else { return "Plus ancien" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "Hier" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }
}

// MARK: - Composants

struct Chip: View {
    let title: String
    var icon: String?
    let isOn: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).imageScale(.small) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isOn ? color : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

struct MetaLine: View {
    let article: Article

    var body: some View {
        HStack(spacing: 4) {
            Text(article.source)
                .fontWeight(.semibold)
                .foregroundStyle(article.category.color)
            if let date = article.date {
                Text("·")
                Text(Calendar.current.isDateInToday(date)
                     ? date.formatted(.relative(presentation: .named))
                     : date.formatted(date: .omitted, time: .shortened))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                MetaLine(article: article)
                Text(article.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let url = article.imageURL {
                RemoteImage(url: url)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct HeroCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = article.imageURL {
                RemoteImage(url: url)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            MetaLine(article: article)
            Text(article.title)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Image distante qui remplit son cadre sans le déformer.
struct RemoteImage: View {
    let url: URL

    var body: some View {
        Color.secondary.opacity(0.12)
            .overlay {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    EmptyView()
                }
            }
            .clipped()
    }
}

extension Category {
    var color: Color {
        switch self {
        case .geo: .indigo
        case .eco: .teal
        case .transport: .orange
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
