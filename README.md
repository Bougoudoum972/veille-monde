# Veille Monde

L'actualité géopolitique, économique et transport du jour, réunie à partir d'une quarantaine de sources (Le Monde, RFI, Jeune Afrique, Revue Conflits, Politico, des flux transport aérien, routier et maritime…).

## Contenu du dépôt

| Dossier | Rôle |
|---|---|
| `docs/` | La web app (HTML, CSS, JS), publiée par GitHub Pages |
| `scripts/fetch_news.py` | Récupère les flux RSS et écrit `docs/news.json` |
| `.github/workflows/update-news.yml` | Lance le script toutes les 30 minutes |
| `VeilleMonde/` | La version app iPhone (SwiftUI, Xcode) |

## Ajouter ou retirer une source

Modifier la liste `FEEDS` dans `scripts/fetch_news.py` (et `Models.swift` pour l'app iPhone). Les thèmes possibles : `world`, `africa`, `defense`, `france`, `global`, `air`, `road`, `sea`, `logistics`.

## Tester en local

```bash
python3 scripts/fetch_news.py
python3 -m http.server 8000 --directory docs
```

Puis ouvrir http://localhost:8000.
