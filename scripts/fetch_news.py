#!/usr/bin/env python3
"""Récupère les flux RSS de Veille Monde et écrit docs/news.json.

Lancé toutes les 30 minutes par GitHub Actions (.github/workflows/update-news.yml).
Aucune dépendance : bibliothèque standard Python uniquement.
"""
import html
import json
import re
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "docs" / "news.json"
PER_FEED = 25

# (source, thème, url) — mêmes sources que l'app iPhone (Models.swift).
FEEDS = [
    # Géopolitique — international
    ("Le Monde", "world", "https://www.lemonde.fr/international/rss_full.xml"),
    ("Le Figaro", "world", "https://www.lefigaro.fr/rss/figaro_international.xml"),
    ("France 24", "world", "https://www.france24.com/fr/rss"),
    ("RFI", "world", "https://www.rfi.fr/fr/rss"),
    ("Courrier International", "world", "https://www.courrierinternational.com/feed/all/rss.xml"),
    ("Politico Europe", "world", "https://www.politico.eu/section/politics/feed/"),
    ("BBC World", "world", "https://feeds.bbci.co.uk/news/world/rss.xml"),
    ("The Guardian", "world", "https://www.theguardian.com/world/rss"),
    ("Al Jazeera", "world", "https://www.aljazeera.com/xml/rss/all.xml"),
    # Géopolitique — Afrique
    ("Le Monde Afrique", "africa", "https://www.lemonde.fr/afrique/rss_full.xml"),
    ("RFI Afrique", "africa", "https://www.rfi.fr/fr/afrique/rss"),
    ("France 24 Afrique", "africa", "https://www.france24.com/fr/afrique/rss"),
    ("Jeune Afrique", "africa", "https://www.jeuneafrique.com/feed/"),
    ("BBC Afrique", "africa", "https://www.bbc.com/afrique/index.xml"),
    ("Africanews", "africa", "https://fr.africanews.com/feed/rss"),
    ("The Africa Report", "africa", "https://www.theafricareport.com/feed/"),
    ("Financial Afrik", "africa", "https://www.financialafrik.com/feed/"),
    # Géopolitique — défense et conflits
    ("Revue Conflits", "defense", "https://www.revueconflits.com/feed/"),
    ("Politico Défense", "defense", "https://rss.politico.com/defense.xml"),
    # Économie — France
    ("Le Monde Éco", "france", "https://www.lemonde.fr/economie/rss_full.xml"),
    ("Le Figaro Éco", "france", "https://www.lefigaro.fr/rss/figaro_economie.xml"),
    ("La Tribune", "france", "https://www.latribune.fr/feed.xml"),
    # Économie — monde
    ("France 24 Éco", "global", "https://www.france24.com/fr/%C3%A9co-tech/rss"),
    ("BBC Business", "global", "https://feeds.bbci.co.uk/news/business/rss.xml"),
    ("The Guardian Business", "global", "https://www.theguardian.com/business/rss"),
    ("CNBC World", "global", "https://www.cnbc.com/id/100727362/device/rss/rss.html"),
    # Transport
    ("Air Journal", "air", "https://www.air-journal.fr/feed"),
    ("Aerobuzz", "air", "https://www.aerobuzz.fr/feed/"),
    ("Journal de l'Aviation", "air", "https://www.journal-aviation.com/rss"),
    ("Air Cargo News", "air", "https://www.aircargonews.net/feed/"),
    ("Transport Info", "road", "https://www.transportinfo.fr/feed/"),
    ("L'Officiel des Transporteurs", "road", "https://www.wk-transport-logistique.fr/rss"),
    ("Flotauto", "road", "https://www.flotauto.com/rss"),
    ("Transport Topics", "road", "https://www.ttnews.com/rss.xml"),
    ("Ports et Corridors", "sea", "https://www.portsetcorridors.com/feed/"),
    ("gCaptain", "sea", "https://gcaptain.com/feed/"),
    ("Splash247", "sea", "https://splash247.com/feed/"),
    ("Seatrade Maritime", "sea", "https://www.seatrade-maritime.com/rss.xml"),
    ("Hellenic Shipping News", "sea", "https://www.hellenicshippingnews.com/feed/"),
    ("The Loadstar", "logistics", "https://theloadstar.com/feed/"),
]

NS = {"atom": "http://www.w3.org/2005/Atom", "media": "http://search.yahoo.com/mrss/"}
EARLIEST = datetime(2000, 1, 1, tzinfo=timezone.utc)


def clean(text, limit=None):
    if not text:
        return ""
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", html.unescape(text)).strip()
    if limit and len(text) > limit:
        text = text[:limit].rstrip() + "…"
    return text


def parse_date(value):
    if not value:
        return None
    value = value.strip()
    dt = None
    try:
        dt = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    if dt < EARLIEST:  # année sur deux chiffres mal lue
        return None
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def find_image(item):
    for tag in ("media:content", "media:thumbnail"):
        for el in item.findall(tag, NS):
            if el.get("url") and el.get("medium", "image") == "image":
                return el.get("url")
    enc = item.find("enclosure")
    if enc is not None and (enc.get("type") or "").startswith("image"):
        return enc.get("url")
    desc = item.findtext("description") or ""
    m = re.search(r'<img[^>]+src="([^"]+)"', desc)
    return m.group(1) if m else None


def fetch(feed):
    source, topic, url = feed
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (VeilleMonde; +github.com)"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            root = ET.fromstring(resp.read())
    except Exception as e:  # noqa: BLE001 — une source en panne ne doit pas bloquer les autres
        print(f"  ✗ {source}: {e}")
        return source, None

    items = root.findall(".//item") or root.findall(".//atom:entry", NS)
    articles = []
    for item in items:
        link = (item.findtext("link") or "").strip()
        if not link:
            el = item.find("atom:link", NS)
            link = el.get("href", "") if el is not None else ""
        title = clean(item.findtext("title") or item.findtext("atom:title", namespaces=NS))
        if not title or not link.startswith("http"):
            continue
        image = find_image(item)
        articles.append({
            "title": title,
            "summary": clean(item.findtext("description") or item.findtext("atom:summary", namespaces=NS), 280),
            "link": link,
            "date": parse_date(item.findtext("pubDate") or item.findtext("{http://purl.org/dc/elements/1.1/}date")
                               or item.findtext("atom:published", namespaces=NS)
                               or item.findtext("atom:updated", namespaces=NS)),
            "image": image if image and image.startswith("https://") else None,
            "source": source,
            "topic": topic,
        })
        if len(articles) >= PER_FEED:
            break
    print(f"  ✓ {source}: {len(articles)}")
    return source, articles or None


def main():
    with ThreadPoolExecutor(max_workers=16) as pool:
        results = list(pool.map(fetch, FEEDS))

    seen, articles, failed = set(), [], []
    for source, items in results:
        if items is None:
            failed.append(source)
            continue
        for a in items:
            if a["link"] not in seen:
                seen.add(a["link"])
                articles.append(a)
    articles.sort(key=lambda a: a["date"] or "", reverse=True)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "failed": sorted(failed),
        "articles": articles,
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(articles)} articles, {len(failed)} source(s) en échec → {OUT}")


if __name__ == "__main__":
    main()
