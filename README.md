<img src="docs/logo-aptitude.png" alt="Logo Aptitude" width="96" align="right">

# Aptitude Threat Map

Mur des attaques pour salle SOC, hébergé dans **Splunk** (Cloud ou Enterprise) :
carte des attaques en direct, compteurs du jour, flux des derniers événements,
équipe de permanence, et relecture de n'importe quel moment de la journée.

![Aperçu du mur](docs/apercu.png)

- **Sans serveur ni jeton** : une appli Splunk. Des recherches planifiées
  calculent, le tableau de bord affiche. Un calcul toutes les 5 minutes, quel
  que soit le nombre d'écrans.
- **Démarre sans données** : l'appli est livrée avec 5 sources de démonstration
  (générées par `makeresults`). Installez-la, le mur s'anime tout de suite.
  Remplacez ensuite les sources, une par une, par les vôtres.
- **Adaptable par configuration** : titre, logo, couleurs, sites protégés,
  sources et leurs recherches SPL tiennent dans un seul fichier,
  `config/wall.json`.
- **Des modèles de sources** pour des produits courants (WAF Ubika, IPS
  Check Point, Proofpoint, échecs de connexion Microsoft 365, VPN F5 APM),
  chacun avec son jeu de test.
- **Un tableau de bord de configuration** : vérifications après installation,
  sources d'attaque (ajout, validation, modification et suppression, sans
  reconstruire l'appli), analystes et photos, planning, état des recherches,
  dépannage.

Interface en français ou en anglais (`"language": "en"`, voir
[README.en.md](README.en.md)).

## Démarrage rapide

```bash
git clone <ce dépôt> && cd soc-attack-wall
python3 build.py                 # config/wall.example.json -> dist/soc_attack_wall-<version>.tgz
xdg-open dist/apercu.html        # la page seule, en simulation, sans Splunk
```

1. Installez `dist/soc_attack_wall-<version>.tgz` dans Splunk
   (*Applications > Gérer les applications > Installer depuis un fichier*).
2. Ouvrez **Configuration** dans l'appli et suivez la section *Démarrage*.
3. Attendez 10 minutes (deux passages des recherches), puis ouvrez **Mur**.

Le détail est dans [docs/INSTALL.md](docs/INSTALL.md).

## L'adapter à votre SOC

```bash
cp config/wall.example.json config/wall.json    # ignoré par git
$EDITOR config/wall.json                         # titre, sites, sources
python3 build.py --verifier                      # contrôle de la configuration
python3 build.py                                 # nouveau paquet
```

Une source, c'est une recherche SPL qui fournit 7 champs : `_time, src_ip, dc,
severity, signature, dest_host, action`. Le reste (géolocalisation,
coordonnées des sites, normalisation) est ajouté par `build.py`. Voir
[docs/ADAPTER.md](docs/ADAPTER.md) et [docs/CONTRAT.md](docs/CONTRAT.md).

## Passer en production

### Retirer les sources de démonstration

L'appli est livrée avec 5 sources de démonstration (`waf`, `ids`, `mail`,
`idp`, `vpn`) qui génèrent de fausses attaques toutes les 5 minutes. En
production, retirez-les de `config/wall.json` : dans la liste `"sources"`,
supprimez les blocs dont `search_file` commence par `sources/demo/`, puis
reconstruisez le paquet. Elles ne seront alors jamais installées, y compris
sur un nouveau serveur.

Sur un Splunk déjà installé, on peut aussi les désactiver dans
**Configuration > Sources d'attaque**. Ce réglage reste dans Splunk et ne
suit pas un nouveau clone.

### Des alertes de démonstration s'affichent encore après la désactivation

Le mur compte **depuis minuit**. Les fausses attaques produites avant la
désactivation restent dans les compteurs, les pays et les techniques jusqu'à
minuit, puis disparaissent seules. Rechargez aussi la page (Ctrl+F5) : le flux
« En direct » garde ses dernières lignes en mémoire.

Pour vérifier qu'elles ne tournent plus (recherche Splunk, 15 dernières
minutes) :

```
index=summary search_name=wall_* NOT meta=1 | stats count latest(_time) as dernier by search_name | convert ctime(dernier)
```

Seules vos vraies sources (`wall_bunkerweb`, `wall_utmstack`…) doivent
apparaître. Sinon, vérifiez leur état :

```
| rest /servicesNS/-/soc_attack_wall/saved/searches search=wall_ | table title disabled is_scheduled
```

Pour repartir d'un mur vide sans attendre minuit, videz l'index `summary`.
**La suppression est définitive** : tout l'historique du mur est effacé, les
journaux bruts (`index=threatmap`) et les réglages sont conservés.

```bash
docker exec -u splunk soc-attack-wall-splunk /opt/splunk/bin/splunk stop
docker exec -u splunk soc-attack-wall-splunk /opt/splunk/bin/splunk clean eventdata -index summary -f
docker restart soc-attack-wall-splunk
```

### Quand faut-il reconstruire le paquet ?

| Changement | Enregistré dans | Reconstruire ? |
|---|---|---|
| Interface de l'appli : sources, planning, analystes, sites, clients | Splunk (volumes Docker) | non, actif en 5 à 10 min |
| `config/wall.json` : titre, logo, couleurs, sources livrées | le paquet | oui |
| Code (`web/`, `splunk_app/src/`) | le paquet | oui |

Pour reconstruire : augmentez `"version"` dans `config/wall.json`, mettez la
même valeur dans `WALL_VERSION` de `.env`, puis :

```bash
python3 build.py && python3 docker/paquet.py
docker compose up -d     # recree le conteneur ; un docker restart garderait l'ancienne version
```

Les réglages faits dans l'interface survivent aux redémarrages et aux mises à
jour, mais pas à `docker compose down -v`, qui supprime les volumes. Ils ne
sont pas dans le dépôt : sauvegardez les volumes Docker.

## Tests

```bash
python3 -m unittest discover -s tests -v          # hors ligne, sans Splunk

export SPLUNK_URL=https://votre-splunk:8089 SPLUNK_TOKEN=...
python3 tests/splunk/run.py --sans-appli          # jeux de tests SPL (lecture seule)
```

Les jeux de tests SPL rejouent chaque modèle de source sur des événements
fictifs (`templates/sources/*/fixture.spl`) et comparent le résultat à
`attendu.json`. Ils vérifient aussi vos propres sources contre le contrat. Ils
ne lisent aucun index et n'écrivent rien.

## Organisation du dépôt

| Chemin | Contenu |
|---|---|
| `config/wall.example.json` | configuration de démonstration, point de départ de la vôtre |
| `config/sources/demo/` | sources de démonstration (générateurs `makeresults`) |
| `templates/sources/` | modèles de sources par produit, avec jeux de test |
| `web/index.html` | la page du mur (s'ouvre aussi seule, en simulation) |
| `splunk_app/src/` | lecture des recherches, tableau de bord de configuration |
| `splunk_app/assets/` | polices, lookups de démonstration |
| `build.py` | construit l'appli et l'aperçu |
| `tests/` | tests hors ligne et jeux de tests SPL |
| `docs/` | installation, adaptation, contrat, architecture, dépannage |

## Licences

Code sous licence MIT (voir [LICENSE](LICENSE)).
Police Barlow Semi Condensed : SIL Open Font License 1.1
(`splunk_app/assets/fonts/OFL-Barlow.txt`). Drapeaux : Twemoji,
CC-BY 4.0, © Twitter, Inc. et contributeurs. Frontières : Natural Earth
(domaine public).
