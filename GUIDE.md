# Guide Veille Monde — que faire si…

Ce guide explique comment utiliser, entretenir et relancer Veille Monde, même sans la discussion d'origine.

## À conserver précieusement

| Quoi | Valeur |
|---|---|
| Adresse de la web app | https://bougoudoum972.github.io/veille-monde/ |
| Dépôt GitHub (le code et la sauvegarde) | https://github.com/Bougoudoum972/veille-monde |
| Compte GitHub | `Bougoudoum972` (mot de passe : à garder dans ton trousseau) |
| Dossier sur le Mac | Documents → dossier veille monde |

**Le plus simple pour tout problème :** ouvrir une session Claude sur le dossier du projet (ou lui donner le lien GitHub) et dire par exemple « Mon site Veille Monde ne marche plus, lis GUIDE.md et répare-le ».

---

## Comment ça marche, en bref

1. Toutes les 30 minutes, GitHub lance `scripts/fetch_news.py`, qui lit les 40 flux RSS.
2. Le résultat est enregistré dans `docs/news.json`.
3. GitHub Pages publie le dossier `docs/` : c'est la web app.
4. Ton iPhone affiche simplement cette page.

Ton Mac n'a pas besoin d'être allumé.

---

## Installer la web app sur un iPhone

1. Ouvrir l'adresse de la web app dans **Safari**.
2. Bouton **Partager** → **Sur l'écran d'accueil** → **Ajouter**.

### L'ouvrir avec Raccourcis, Siri ou chaque matin

1. App **Raccourcis** → **+** → **Ajouter une action** → **Ouvrir les URL**.
2. Coller l'adresse de la web app, renommer le raccourci **Veille Monde**.
3. Siri : « Dis Siri, Veille Monde ».
4. Chaque matin : onglet **Automatisation** → **+** → **Heure de la journée** → choisir l'heure, **Quotidiennement**, **Exécuter immédiatement** → raccourci **Veille Monde**.

---

## Que faire si…

### Les actualités ne se mettent plus à jour

Signe : en bas de la liste, « Mis à jour à … » indique une heure ancienne.

1. Aller sur le dépôt GitHub → onglet **Actions**.
2. Si un bandeau jaune indique que le workflow est désactivé : cliquer sur **Enable workflow**.
   (GitHub met en pause les tâches planifiées d'un dépôt inactif depuis 60 jours.)
3. À gauche, cliquer sur **Mise à jour des actualités** → bouton **Run workflow** → **Run workflow**.
4. Attendre 1 à 2 minutes, puis toucher ↻ dans l'app.

Si la tâche apparaît en rouge (échec), cliquer dessus pour voir l'erreur, ou demander à Claude.

### Le site affiche une erreur 404 ou ne s'ouvre plus

1. Dépôt GitHub → **Settings** → **Pages** (menu de gauche).
2. Vérifier : **Source = Deploy from a branch**, **Branch = main**, dossier **/docs**. Cliquer sur **Save**.
3. Attendre 2 minutes et recharger le site.

### Une source n'apparaît plus

En bas de la liste, la ligne « Indisponible : … » liste les sources en panne. Souvent, c'est temporaire et ça revient tout seul. Si une source reste en panne plusieurs jours, son adresse RSS a probablement changé : demander à Claude de la vérifier et de la remplacer.

> Air Cargo News bloque les serveurs de GitHub : elle apparaît dans l'app iPhone mais pas dans la web app.

### Je veux ajouter ou retirer une source

Le plus simple : demander à Claude « Ajoute la source X dans Veille Monde ».

À la main, depuis le site GitHub :
1. Ouvrir `scripts/fetch_news.py` dans le dépôt, cliquer sur le crayon ✏️.
2. Dans la liste `FEEDS`, ajouter une ligne sur le modèle des autres :
   `("Nom de la source", "theme", "https://adresse-du-flux-rss"),`
   Thèmes possibles : `world`, `africa`, `defense` (Géopolitique) · `france`, `global` (Économie) · `air`, `road`, `sea`, `logistics` (Transport).
3. Cliquer sur **Commit changes**. La mise à jour se lance toute seule.

### J'ai perdu mon Mac (ou j'en change)

Tout est sur GitHub. Sur le nouvel ordinateur, ouvrir une session Claude et dire : « Récupère mon projet github.com/Bougoudoum972/veille-monde dans Documents ». Le site, lui, continue de fonctionner sans interruption.

### Le dépôt GitHub a été supprimé

Le site est alors hors ligne, mais le dossier sur le Mac contient tout. Ouvrir une session Claude sur ce dossier et dire : « Recrée mon dépôt GitHub veille-monde et republie le site ». Il faudra se reconnecter à GitHub avec un code, comme la première fois.

### J'ai oublié mon mot de passe GitHub

Aller sur https://github.com/password_reset et suivre les étapes avec l'e-mail du compte. Le site continue de fonctionner pendant ce temps.

### L'app iPhone « native » (installée depuis le Mac) ne s'ouvre plus

C'est normal tous les 7 jours avec un compte Apple gratuit. Brancher l'iPhone au Mac, le déverrouiller, puis double-cliquer sur **Réinstaller Veille Monde.command** dans le dossier du projet. Si tu n'utilises plus que la web app, tu peux simplement supprimer cette app de l'iPhone.

---

## Contenu du dossier

| Élément | Rôle |
|---|---|
| `docs/` | La web app (page, style, code, icônes, actualités) |
| `scripts/fetch_news.py` | Lit les flux RSS et écrit `docs/news.json` |
| `.github/workflows/update-news.yml` | Lance le script toutes les 30 minutes sur GitHub |
| `VeilleMonde/` | L'app iPhone native (Xcode) |
| `Réinstaller Veille Monde.command` | Réinstalle l'app iPhone native en un double-clic |
| `GUIDE.md` | Ce guide |
