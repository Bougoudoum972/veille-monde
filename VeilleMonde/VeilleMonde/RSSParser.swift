import Foundation

/// Lit un flux RSS 2.0 ou Atom et le transforme en articles.
final class RSSParser: NSObject, XMLParserDelegate {
    private let feed: Feed
    private var articles: [Article] = []

    private var inItem = false
    private var text = ""
    private var title = ""
    private var link = ""
    private var summary = ""
    private var dateString = ""
    private var image: String?

    init(feed: Feed) {
        self.feed = feed
    }

    func parse(_ data: Data) -> [Article] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = (qName ?? elementName).lowercased()
        text = ""
        if name == "item" || name == "entry" {
            inItem = true
            title = ""; link = ""; summary = ""; dateString = ""; image = nil
            return
        }
        guard inItem else { return }
        switch name {
        case "link":
            if link.isEmpty, let href = attributes["href"], (attributes["rel"] ?? "alternate") == "alternate" {
                link = href
            }
        case "media:content", "media:thumbnail":
            if image == nil, let url = attributes["url"], (attributes["medium"] ?? "image") == "image" {
                image = url
            }
        case "enclosure":
            if image == nil, let url = attributes["url"], (attributes["type"] ?? "").hasPrefix("image") {
                image = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        guard inItem else { return }
        let name = (qName ?? elementName).lowercased()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""

        switch name {
        case "title":
            if title.isEmpty { title = value }
        case "link":
            if link.isEmpty { link = value }
        case "description", "summary":
            if summary.isEmpty { summary = value }
        case "pubdate", "published", "updated", "dc:date":
            if dateString.isEmpty { dateString = value }
        case "item", "entry":
            inItem = false
            finishItem()
        default:
            break
        }
    }

    private func finishItem() {
        let cleanTitle = title.strippingHTML
        guard !cleanTitle.isEmpty,
              let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }

        if image == nil, let range = summary.range(of: #"<img[^>]+src="([^"]+)""#, options: .regularExpression) {
            image = String(summary[range]).components(separatedBy: "src=\"").last?.dropLast().description
        }

        var cleanSummary = summary.strippingHTML
        if cleanSummary.count > 280 { cleanSummary = String(cleanSummary.prefix(280)) + "…" }

        articles.append(Article(
            id: url.absoluteString,
            title: cleanTitle,
            summary: cleanSummary,
            link: url,
            date: DateParser.parse(dateString),
            imageURL: image.flatMap { URL(string: $0) }.flatMap { $0.scheme == "https" ? $0 : nil },
            source: feed.source,
            topic: feed.topic
        ))
    }
}

enum DateParser {
    private static let rfc822: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm Z",
        "EEE, dd MMM yy HH:mm:ss Z",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    private static let iso: [ISO8601DateFormatter] = {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [plain, fractional]
    }()

    /// Écarte les années mal lues (« 26 » interprété comme l'an 26).
    private static let earliest = Date(timeIntervalSince1970: 946_684_800)

    static func parse(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        for f in rfc822 { if let d = f.date(from: string), d > earliest { return d } }
        for f in iso { if let d = f.date(from: string) { return d } }
        return nil
    }
}

extension String {
    /// Retire les balises HTML et décode les entités courantes.
    var strippingHTML: String {
        var s = replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&rsquo;": "’", "&lsquo;": "‘", "&ldquo;": "“",
            "&rdquo;": "”", "&hellip;": "…", "&mdash;": "—", "&ndash;": "–", "&eacute;": "é",
            "&egrave;": "è", "&agrave;": "à", "&ccedil;": "ç", "&ecirc;": "ê",
        ]
        for (entity, char) in entities { s = s.replacingOccurrences(of: entity, with: char) }
        while let range = s.range(of: "&#(x?[0-9a-fA-F]+);", options: .regularExpression) {
            let code = s[range].dropFirst(2).dropLast()
            let scalar = code.hasPrefix("x") || code.hasPrefix("X")
                ? UInt32(code.dropFirst(), radix: 16)
                : UInt32(code)
            let replacement = scalar.flatMap { Unicode.Scalar($0) }.map { String(Character($0)) } ?? ""
            s.replaceSubrange(range, with: replacement)
        }
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
