# Spécification technique — Application macOS de culling & analyse compositionnelle pour Leica Q3 (Flutter)

## TL;DR
- **Application Flutter desktop macOS de tri (« culling ») ultra-rapide travaillant directement sur la carte SD du Leica Q3**, avec affichage instantané des vignettes via extraction du JPEG embarqué dans les DNG (jamais de dématriçage RAW complet pour la grille), navigation clavier, suppression atomique de la paire DNG+JPG, recadrage non destructif exporté sur le Mac, mode « vision obscura » (rotation 180°) et calques de composition vectoriels issus de la « Grammaire du cadre ».
- **La sécurité de la carte est l'exigence dominante** : respect strict de la norme DCF 2.0 (arborescence `DCIM/100LEICA`, nommage 8.3 `L100XXXX`), écritures atomiques + `fsync`, éjection propre, et interdiction absolue d'écrire des fichiers parasites macOS (`.DS_Store`, `._AppleDouble`, `.Spotlight-V100`, `.fseventsd`) sur la carte exFAT non journalisée.
- **Pile technique recommandée** : Flutter desktop sandboxé + security-scoped bookmarks pour l'accès persistant à `/Volumes`, Riverpod pour le state, isolates pour le décodage, base de données **Drift (SQLite)** stockée sur le Mac pour la bibliothèque de calques et leurs transformations par photo, clé stable dérivée du radical DCF + EXIF.

---

## Key Findings

1. **Le Q3 facilite l'affichage rapide.** Chaque DNG du Leica Q3 embarque une preview JPEG **pleine résolution** en plus de miniatures réduites — la communauté Leica le confirme (« Leica stores a full-size preview in the DNG so that we can check focus at 100% »). L'app peut donc afficher grille et visionneuse **sans jamais dématricer le RAW**, ce qui est la clé de l'efficacité. La résolution native maximale est **9520 × 6336 px (60,3 Mpx effectifs)**, capteur CMOS 62,39 Mpx total, DNG 14 bits, JPG 8 bits sRGB, conforme DCF 2.0 / Exif 2.31 (fiche technique officielle Leica, mai 2023).

2. **La structure de carte est standardisée et fragile.** Le Q3 écrit `DCIM/100LEICA/`, `101LEICA/`… (max 999 dossiers), fichiers `L1000001.DNG/.JPG` → `L1009999`, puis nouveau dossier. Le manuel Leica ne documente **aucun** fichier annexe pour les photos (pas de `.THM`, pas d'index, pas de dossier MISC) — uniquement des DNG/JPG dans `DCIM/###LEICA/`. La carte est généralement en **exFAT non journalisé**, donc vulnérable à la corruption sur retrait/coupure : c'est pourquoi la spécification impose écritures atomiques, corbeille hors-carte et éjection propre.

3. **La pile Flutter est mature pour ce besoin.** Sandbox + security-scoped bookmarks (docs Apple + Flutter) permettent l'accès persistant à la carte ; `InteractiveViewer` gère zoom/pan trackpad ; `Shortcuts`/`Actions`/`Intent` gèrent les raccourcis sans plugin ; les isolates déchargent le décodage ; **Drift** est le choix de base de données recommandé en 2026 (Hive et Isar étant abandonnés par leur auteur d'origine).

---

## 1. Vision produit et principes

L'application vise un usage précis : un photographe équipé d'un **Leica Q3** souhaite, dès le retour d'une session, **trier, supprimer et recadrer** ses images **directement sur la carte SD**, sans étape d'import préalable, avec une efficacité maximale.

Trois principes directeurs, par ordre de priorité :

1. **Sécurité de la carte avant tout.** La carte doit rester parfaitement lisible et exploitable par le Q3 après usage. Aucune opération ne doit casser la structure DCF, les index de nommage, ni introduire de fichiers parasites. Toute écriture est atomique et confirmée (`fsync`). En cas de doute, l'application refuse d'écrire.
2. **Non-destructif.** Le DNG original n'est jamais modifié ni réencodé. Le recadrage produit des **exports** sur le Mac. La suppression est la seule opération destructive et elle est protégée par une corbeille hors-carte.
3. **Efficacité (culling rapide).** Tout est optimisé pour la vitesse perçue : vignettes issues des previews JPEG embarquées, navigation clavier, préchargement, gestes trackpad natifs.

## 2. Parcours utilisateur types

**A. Culling d'une session photo.** L'utilisateur insère la carte, ouvre l'app, sélectionne le volume (`/Volumes/LEICA Q3` ou nom donné à la carte). L'app scanne `DCIM/`, construit une grille de vignettes. Il navigue au clavier (flèches), ouvre en grand (Entrée/Espace), marque à supprimer (Suppr) ou valide, enchaîne next/previous très vite. À la fin il vide la corbeille (suppression réelle atomique) puis éjecte proprement la carte via l'app.

**B. Analyse de composition.** Sur une image ouverte, il bascule en **vision obscura** (image retournée à 180°, touche O) pour neutraliser le sujet et juger l'équilibre des masses. Il dépose un ou plusieurs **calques** issus de la Grammaire du cadre (spirale d'or, tiers, diagonales, lignes de force), les déplace et redimensionne via poignées pour les caler sur l'image. Les transformations sont sauvegardées par photo.

**C. Recadrage / export.** Il passe en mode recadrage, choisit un ratio **standard uniquement** (3:2, 4:3, 5:4, 1:1, 16:9, 65:24 XPan), ajuste le cadre, choisit portrait/paysage, exporte. Le fichier recadré est écrit dans un dossier d'export sur le Mac ; le DNG reste intact sur la carte.

## 3. Exigences fonctionnelles détaillées

### 3.1 Grille de vignettes performante

- **FONC-GRID-1 (source des vignettes).** La grille affiche **exclusivement la preview JPEG embarquée** dans le DNG (ou le JPG frère s'il existe), **jamais** le résultat d'un dématriçage RAW complet. L'app extrait la miniature réduite (petit IFD, de l'ordre de 256 px) pour la grille et réserve la preview pleine taille pour la visionneuse. *(Note : les dimensions exactes des previews embarquées d'un DNG Q3 doivent être confirmées par un `exiftool -a -G1` sur un fichier réel ; le motif DNG classique est IFD0 = miniature réduite ~256 px, un IFD intermédiaire ~1024 px, et un SubIFD contenant la preview JPEG pleine taille. Leica place sa preview JPEG dans une structure APP1 IFD2/SubIFD, comme documenté dans le code source d'ExifTool.)*
- **FONC-GRID-2 (paires DNG+JPG).** Le Q3 en mode « DNG + JPG » écrit deux fichiers de même radical (`L1000001.DNG` + `L1000001.JPG`). L'app les regroupe en une **entité photo unique** identifiée par le radical 8.3, avec une seule vignette et un badge « RAW+JPG ».
- **FONC-GRID-3 (cache disque).** Les vignettes décodées sont mises en cache **sur le Mac** (répertoire application-support), jamais sur la carte, indexées par la clé stable de la photo (§7). Le cache est réutilisé entre sessions.
- **FONC-GRID-4 (décodage hors UI-thread).** L'extraction/décodage se fait dans des **isolates** (pool de workers) pour ne jamais bloquer le thread UI ; la grille affiche des placeholders (couleur moyenne / ThumbHash via `fast_thumbhash`) tant que la vignette n'est pas prête.

### 3.2 Visionneuse et navigation

- **FONC-VIEW-1.** Ouverture plein cadre depuis la grille (double-clic ou Entrée). L'image affichée est la **preview pleine résolution** embarquée (jusqu'à 9520 × 6336 px, résolution native maximale du Q3 confirmée par DPReview et la fiche Leica) ; pour un rendu 1:1 net on peut demander à la volée un décodage supérieur.
- **FONC-VIEW-2 (navigation rapide).** Flèches gauche/droite = photo précédente/suivante. Préchargement des N images voisines (preview) dans les isolates pour que next/previous soit instantané.
- **FONC-VIEW-3.** Affichage des métadonnées EXIF clés (focale équivalente / crop, vitesse, ouverture, ISO) en surimpression optionnelle. Rappel utile : selon DPReview (« Leica Q3 initial review »), le Q3 propose des crops 35, 50, 75 et 90 mm donnant respectivement des JPEG de **39, 19, 8 et 6 Mpx**, le DNG restant plein format à 9520 × 6336 (60,3 Mpx) ; le crop numérique n'affecte que le JPG, jamais le DNG.

### 3.3 Suppression totale et sûre

- **FONC-DEL-1 (suppression = toute l'entité).** Supprimer une photo supprime **tous les fichiers du même radical** : `.DNG`, `.JPG` et tout fichier annexe partageant le numéro (au sens « DCF object »). L'app calcule l'ensemble avant d'agir et l'affiche dans la confirmation.
- **FONC-DEL-2 (corbeille hors-carte, sécurité).** Par défaut, « supprimer » **déplace** les fichiers vers une corbeille applicative **sur le Mac** (pas `.Trashes` sur la carte, qui polluerait le volume). Deux modes : (a) marquage différé (les fichiers restent sur la carte jusqu'à « Vider la corbeille ») ; (b) déplacement immédiat vers la corbeille Mac. La suppression définitive sur la carte n'intervient qu'à la validation explicite.
- **FONC-DEL-3 (préservation des index DCF).** La suppression **ne renumérote jamais** les fichiers restants et ne touche pas aux noms des autres fichiers ni aux dossiers `100LEICA`. Le compteur du boîtier est indépendant : retirer des fichiers ne le perturbe pas (le Q3 continue d'incrémenter à partir du dernier numéro connu).

### 3.4 Recadrage non destructif, ratios standard uniquement

- **FONC-CROP-1 (ratios autorisés).** L'interface **n'autorise que** : 3:2, 4:3, 5:4, 1:1, 16:9, et 65:24 (panoramique XPan). Chaque ratio est proposé en **paysage et portrait** (sauf 1:1). Aucun ratio libre n'est possible.
- **FONC-CROP-2 (non destructif + export).** Le recadrage ne modifie jamais le DNG. Il produit un **nouveau fichier exporté** dans un **dossier d'export sur le Mac** (paramétrable, par défaut `~/Pictures/Q3Culling/Exports/<date-session>/`). Nommage : `<radical>_<ratio>_<index>.jpg` (ex. `L1000001_3x2_01.jpg`).
- **FONC-CROP-3 (pipeline source).** L'export part de la **preview pleine résolution** embarquée (rapide, déjà en sRGB 8 bits, cohérent avec le rendu JPG boîtier) pour la V1 ; une option « qualité maximale » (dématriçage du DNG via FFI LibRaw) est prévue en évolution. Métadonnées EXIF essentielles copiées depuis la source (dates, modèle, focale) ; espace couleur sRGB (l'espace natif JPG du Q3). Package de recadrage recommandé : **`crop_your_image`** (Dart pur, UI personnalisable, multiplateforme desktop, `aspectRatio` configurable via `CropController`).

### 3.5 Vision obscura

- **FONC-OBS-1.** Bascule instantanée (touche O) affichant l'image **retournée à 180°** (rotation, pas miroir), reproduisant l'image inversée de la chambre noire pour neutraliser la lecture du sujet et juger la composition. **Aucun assombrissement / masquage.** La bascule est un simple `Transform.rotate(pi)` sans réencodage.
- **FONC-OBS-2.** Compatible avec les calques : les calques peuvent être posés et manipulés en mode obscura comme en mode normal (champ `obscura` dans le modèle de données).

### 3.6 Zoom / pan

- **FONC-ZOOM-1.** Zoom via pinch trackpad, molette, double-clic (toggle 100%/ajusté) et raccourcis (⌘+ / ⌘- / ⌘0). Pan par glisser (deux doigts trackpad) fluide. Basé sur `InteractiveViewer` avec `TransformationController`. Attention au changement de comportement trackpad depuis Flutter 3.3 (les gestes trackpad envoient désormais des séquences `PointerPanZoom`) ; le paramètre `trackpadPanShouldActAsZoom` permet de rétablir le zoom au two-finger scroll si souhaité.

### 3.7 Système de calques de composition

- **FONC-LAY-1 (bibliothèque).** 30 patterns issus de `grammaire-du-cadre.html` (formes SVG : lignes de force, spirales, grilles, diagonales, triangles, etc.). Chaque pattern est une **description vectorielle** rendue via `CustomPainter`/`Canvas`.
- **FONC-LAY-2 (instanciation).** Déposer un calque crée une **instance** liée à la photo, avec transformation (position, échelle, rotation optionnelle, opacité, couleur du trait).
- **FONC-LAY-3 (manipulation directe).** L'instance affiche des **poignées** (coins pour l'échelle, centre pour le déplacement) rendues et testées au clic dans le `CustomPainter`. Redimensionnement par poignée = changement d'échelle homogène ou libre.
- **FONC-LAY-4 (persistance).** La bibliothèque de calques et les instances par photo (avec transformations) sont stockées dans une **base fichier sur le Mac** (§7), jamais sur la carte, avec clé stable par photo.

## 4. Exigences non fonctionnelles

- **PERF-1.** Affichage de la première rangée de vignettes < 500 ms après scan ; grille de plusieurs centaines de DNG scrollable à 60 fps grâce au cache et au décodage en isolates.
- **PERF-2.** Navigation next/previous perçue comme instantanée (< 100 ms) grâce au préchargement.
- **PERF-3.** Zoom/pan à 60 fps minimum, sans jank, sur image pleine résolution.
- **FIAB-1.** Aucune opération d'écriture sur la carte n'est laissée dans un état intermédiaire : soit elle réussit et est confirmée (`fsync`), soit elle est annulée proprement.
- **SECU-CARTE (voir §8).** Zéro fichier parasite écrit sur la carte ; respect DCF ; éjection propre obligatoire.
- **MEM-1.** Gestion mémoire stricte : les grandes images (un DNG Q3 pèse environ 70 Mo, preview JPEG pleine taille de plusieurs Mo) sont libérées dès qu'elles sortent de la fenêtre de préchargement ; pas plus de N previews pleine taille en RAM simultanément.

## 5. Spécification UI/UX

### Écrans

1. **Sélecteur de volume / dossier.** Liste les volumes amovibles montés ; bouton « Ouvrir la carte » via `NSOpenPanel`/`file_selector` (obligatoire pour obtenir le droit sandbox) ; mémorisation via security-scoped bookmark.
2. **Grille.** Vignettes carrées ou au ratio réel, badges (RAW+JPG, marqué-à-supprimer, recadré/exporté), barre d'état (nombre d'images, espace carte, sélection).
3. **Visionneuse.** Image plein cadre, overlay EXIF optionnel, barre d'actions (obscura, calques, recadrage, supprimer).
4. **Mode recadrage.** Sélecteur de ratios (boutons segmentés), toggle portrait/paysage, cadre déplaçable/redimensionnable, bouton Exporter.
5. **Mode obscura.** Identique à la visionneuse mais image retournée 180°.
6. **Panneau calques.** Palette des 30 patterns (aperçus SVG), liste des calques posés sur la photo courante avec opacité/couleur/verrou, poignées sur le canvas.

### Tableau des raccourcis clavier

| Raccourci | Action |
|---|---|
| ← / → | Photo précédente / suivante |
| ↑ / ↓ | Rangée précédente / suivante (grille) |
| Entrée / Espace | Ouvrir en grand / revenir à la grille |
| O | Basculer vision obscura |
| Suppr (⌫) | Marquer / déplacer vers corbeille |
| ⌘⌫ | Vider la corbeille (suppression définitive) |
| C | Entrer en mode recadrage |
| 1..6 | Choisir un ratio (3:2, 4:3, 5:4, 1:1, 16:9, 65:24) |
| R | Basculer portrait / paysage du cadre |
| ⌘E | Exporter le recadrage |
| L | Ouvrir / fermer le panneau calques |
| ⌘+ / ⌘- / ⌘0 | Zoom avant / arrière / réinitialiser |
| Double-clic | Toggle 100% / ajusté |
| ⌘Z / ⌘⇧Z | Annuler / rétablir (calques, marquage) |
| ⌘⏏ | Éjecter proprement la carte |

Implémentation : widgets `Shortcuts` + `Actions` + `Intent` + `Focus` de Flutter (aucun plugin externe requis) ; `LogicalKeyboardKey.meta` pour ⌘ sur macOS.

## 6. Architecture technique Flutter

### 6.1 Accès à la carte (sandbox macOS)

- **Entitlements** (à répliquer dans `Runner-Release.entitlements` **ET** `Runner-DebugProfile.entitlements`, en éditant les fichiers directement plutôt que via l'UI Xcode qui ne met à jour qu'un seul fichier) :
  - `com.apple.security.app-sandbox` = `true`
  - `com.apple.security.files.user-selected.read-write` = `true`
  - `com.apple.security.files.bookmarks.app-scope` = `true`
- **Accès persistant** : après que l'utilisateur a choisi le volume via `NSOpenPanel`, créer un **security-scoped bookmark** pour rouvrir la carte lors des sessions suivantes. Appeler `startAccessingSecurityScopedResource` **avant** accès et `stopAccessingSecurityScopedResource` **après** (Apple avertit : « If you fail to relinquish your access to file-system resources when you no longer need them, your app leaks kernel resources »).
- **Packages** : `file_selector` (sélection de dossier/volume) ; `macos_secure_bookmarks` (authpass) ou `directory_bookmarks` pour la persistance des bookmarks (ce dernier documente exactement les trois entitlements ci-dessus).
- **Distribution hors App Store** : **Hardened Runtime** activé (requis pour la notarisation) + signature **Developer ID Application** + notarisation via `notarytool` + `stapler` (stapling du ticket). La doc Flutter le confirme : « If you choose to distribute your application outside of the App Store, you need to notarize your application for compatibility with macOS. This requires enabling the Hardened Runtime option. » L'App Sandbox n'est strictement obligatoire que pour l'App Store, mais on le conserve ici pour la discipline d'accès.

### 6.2 Décodage DNG / previews

- **Stratégie recommandée V1** : extraction du **JPEG embarqué** via lecture des IFD/EXIF du DNG. Package : **`exif_reader`** (Dart, décode l'EXIF de TIFF/JPEG/DNG/RAW et permet de localiser les previews), décodage JPEG via `dart:ui`/`image`. **Jamais de réencodage du DNG.**
- **Option qualité (V2)** : **`flutter_libraw`** (wrapper FFI de LibRaw, publisher vérifié **limeslice.org**, version 0.0.2 publiée le 21 sept. 2024, licence MIT, dépendance unique `ffi ^2.1.3`, supporte macOS). Sa fiche pub.dev liste explicitement l'extraction de « Embedded preview / thumbnail » et le dématriçage complet. **Caveat** : le projet est explicitement « still in its early stages and so may not yet provide complete/full functionality » et l'adoption est faible ; vérifier que l'API Dart d'extraction de preview existe en v0.0.2 avant de s'y fier. LibRaw au niveau natif supporte de façon certaine l'extraction (`unpack_thumb`). Alternative : bindings FFI maison vers LibRaw via `ffigen` (depuis Flutter 3.38, template `package_ffi` avec build hooks recommandé).
- **Isolates** : tout décodage lourd via `compute()` (tâches ponctuelles — « handles 80% of real-world Flutter concurrency needs ») ou un pool d'isolates persistants (`Isolate.spawn` + `TransferableTypedData`/`Uint8List`) pour le batch de vignettes. Rappel : le décodage image est très coûteux en debug mais rapide en release.

### 6.3 Rendu / interactions

- **Zoom/pan** : `InteractiveViewer` + `TransformationController`.
- **Calques & poignées** : `CustomPainter` sur un `Canvas` superposé à l'image, avec hit-testing manuel des poignées ; transformations stockées en **coordonnées normalisées** (indépendantes de la taille d'affichage).
- **Raccourcis** : `Shortcuts` / `Actions` / `Intent` (API native Flutter).

### 6.4 State management & structure

- **State** : **Riverpod** (recommandé comme choix par défaut équilibré en 2026 — type-safe, sécurité à la compilation, faible boilerplate, DI sans `BuildContext`, testable). Alternative : Bloc pour une discipline événementielle stricte.
- **Modules** : `card_access/` (montage, bookmarks, éjection), `catalog/` (scan DCF, entités photo, clé stable), `thumbnails/` (isolates, cache), `viewer/` (zoom, obscura), `crop/` (ratios, export), `layers/` (bibliothèque, instances, painter), `data/` (Drift), `safety/` (écritures atomiques, nettoyage dotfiles, éjection).

## 7. Modèle de données (base fichier des calques)

**Choix technique : Drift (SQLite).** Justification appuyée par l'analyse Luci Studio « The Flutter Local Database Landscape in 2026 » (rédigée pour Flutter 3.44 / Dart 3.12) : « Hive and Isar were abandoned by their original author; Realm's sync was killed by MongoDB. Teams that bet on them are writing migration code instead of features. » Sa recommandation explicite : « **Default to Drift. SQL-backed, type-safe, actively maintained, reactive, built-in isolate threading, works everywhere including web.** » Pour un besoin purement local sans ORM, `sqflite` reste une alternative valable ; du JSON pur suffirait pour un MVP, mais Drift offre requêtes typées et migrations robustes pour peu de surcoût.

**Emplacement** : fichier `.sqlite` dans `~/Library/Application Support/<app>/` sur le Mac. **Jamais sur la carte SD.**

**Clé stable par photo (CLE-PHOTO).** La carte peut être remontée à un point de montage différent ; le chemin absolu n'est donc pas stable. Clé composite recommandée : `radical DCF` (ex. `100LEICA/L1000001`) + `EXIF DateTimeOriginal` + `numéro de série boîtier` (EXIF) + `taille+mtime du DNG` en secours. Un hash de ces champs donne un identifiant robuste au remontage et évite les collisions entre cartes ou dossiers réinitialisés (le Q3 peut réutiliser `100LEICA`/`L1000001` après un « Reset Image Numbering »).

**Schéma concret :**

```sql
-- Bibliothèque de patterns (les 30 de la Grammaire du cadre)
CREATE TABLE pattern (
  id            INTEGER PRIMARY KEY,
  code          TEXT UNIQUE,        -- ex. 'golden_spiral'
  nom           TEXT,
  categorie     TEXT,               -- lignes de force, spirales, grilles...
  svg           TEXT,               -- description vectorielle (chemin SVG / primitives)
  aspect_ratio  REAL                -- ratio de référence si pertinent
);

-- Photos connues (clé stable, pas le chemin volatil)
CREATE TABLE photo (
  id             INTEGER PRIMARY KEY,
  cle_stable     TEXT UNIQUE,       -- hash CLE-PHOTO
  radical_dcf    TEXT,              -- '100LEICA/L1000001'
  date_origin    TEXT,             -- EXIF DateTimeOriginal
  serial_boitier TEXT,
  dng_present    INTEGER, jpg_present INTEGER
);

-- Instances de calques posés sur une photo
CREATE TABLE layer_instance (
  id            INTEGER PRIMARY KEY,
  photo_id      INTEGER REFERENCES photo(id),
  pattern_id    INTEGER REFERENCES pattern(id),
  pos_x         REAL,   -- coordonnées normalisées 0..1
  pos_y         REAL,
  scale_x       REAL,
  scale_y       REAL,
  rotation      REAL,   -- radians
  opacity       REAL,
  color         INTEGER, -- ARGB
  z_index       INTEGER,
  locked        INTEGER,
  obscura       INTEGER  -- posé en mode obscura ?
);

-- Recadrages exportés (traçabilité, non destructif)
CREATE TABLE crop_export (
  id            INTEGER PRIMARY KEY,
  photo_id      INTEGER REFERENCES photo(id),
  ratio         TEXT,   -- '3:2','65:24'...
  orientation   TEXT,   -- 'landscape'/'portrait'
  rect_x REAL, rect_y REAL, rect_w REAL, rect_h REAL, -- normalisé
  export_path   TEXT,   -- chemin sur le Mac
  created_at    TEXT
);
```

## 8. Intégrité de la carte SD (section critique)

**Contexte technique.** Les cartes SD du Q3 sont généralement en **exFAT** (SDXC > 32 Go) ou FAT32 (SDHC). **exFAT n'est pas journalisé** : selon DiskGenius (« NTFS vs FAT32 vs exFAT »), « Like FAT32, exFAT does not maintain a transaction journal. If a drive is disconnected during a write operation, the risk of file system corruption is higher than with NTFS. » De plus, exFAT **n'a qu'une seule table d'allocation**, là où FAT32 en a deux : comme le résume un intervenant technique sur les forums MacRumors, « FAT32 and older FAT-based file systems used two (2) alternating File Allocation Tables. exFAT uses only one. With two FATs, the file system has an opportunity to repair itself if one table is corrupted. Having only one table, exFAT does not have this opportunity. » Règle d'or de l'industrie (OWC/MacSales) : exFAT convient pour des transferts, pas pour un usage actif intensif. D'où les mesures ci-dessous.

- **CARTE-1 (respect DCF 2.0).** Ne jamais renommer, renuméroter ou déplacer les fichiers/dossiers du boîtier. Préserver l'arborescence `DCIM/###LEICA/` et le nommage 8.3 `L100XXXX.DNG/.JPG`. La norme DCF (JEITA CP-3461 / CIPA DC-009) impose un dossier racine `DCIM`, des sous-dossiers `100–999` + 5 caractères, et des noms 8.3 (4 caractères + 4 chiffres). Le radical 8.3 est la seule identité fichier à préserver. Le manuel Leica confirme la mécanique : « The first folder is assigned the name "100LEICA", the second "101LEICA"… the first file is named "L1000001.XXX"… Once file number 9999 is reached, then a new folder will be automatically created. »
- **CARTE-2 (aucun fichier parasite).** macOS a tendance à écrire `.DS_Store`, `._AppleDouble` (`._*`), `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems` sur les volumes externes. L'app doit :
  - Désactiver l'indexation Spotlight du volume (créer `.metadata_never_index` ou `mdutil -i off -d /Volumes/<carte>`).
  - Empêcher les `.DS_Store` sur volumes USB (`defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true`).
  - Ne jamais utiliser `.Trashes` de la carte (corbeille hors-carte, cf. §3.3).
  - Proposer un **nettoyage** de ces fichiers avant éjection (`dot_clean -m`, suppression ciblée des dotfiles) uniquement à la demande de l'utilisateur.
- **CARTE-3 (écritures atomiques + durabilité).** Bien que l'app n'écrive normalement rien sur la carte (exports sur le Mac), toute écriture éventuelle suit le protocole standard : écrire dans un fichier temporaire → `fsync(fichier)` → `rename` atomique → `fsync(répertoire)`. Une suppression est une opération unitaire et vérifiée.
- **CARTE-4 (montage/démontage propre).** Détecter le montage/démontage du volume. Fournir un bouton **Éjecter** (⌘⏏) qui flush et démonte proprement (`diskutil eject`). Avertir si l'utilisateur retire la carte sans éjecter.
- **CARTE-5 (retrait en cours d'opération).** Si le volume disparaît pendant une opération, l'app détecte l'erreur d'E/S, stoppe immédiatement, marque l'entité concernée comme « incertaine » et propose un re-scan au remontage ; aucune donnée du Mac (corbeille, cache) n'est perdue.
- **CARTE-6 (suppression sûre).** La suppression ne touche que les fichiers ciblés, ne réécrit aucun index, préserve les autres « DCF objects ».
- **CARTE-7 (recommandation corbeille hors-carte).** Confirmée : la corbeille de récupération vit sur le Mac, pas sur la carte, pour éviter `.Trashes` et limiter les écritures sur exFAT.

## 9. Gestion des erreurs et cas limites

- **Carte retirée brutalement** : détection E/S, arrêt, état « incertain », re-scan au remontage (CARTE-5).
- **Paire DNG/JPG incomplète** (DNG seul — cas du mode « DNG only », où même un Leica Look reste visible uniquement dans la preview embarquée — ou JPG orphelin) : l'entité s'affiche quand même ; badge indiquant le(s) format(s) présent(s) ; la suppression retire ce qui existe.
- **DNG corrompu / preview illisible** : fallback sur miniature réduite, sinon vignette « erreur » ; l'image reste supprimable.
- **Carte pleine** : les exports allant sur le Mac, la carte pleine n'empêche ni le culling ni l'export ; seule une écriture sur carte (rare) échouerait proprement.
- **Fichiers verrouillés / lecture seule** (onglet de protection SD, permissions) : l'app détecte, informe, et désactive les actions destructives sans planter.
- **Volume remonté à un autre point de montage** : la clé stable (§7) retrouve les calques/exports associés.
- **Reset de numérotation du boîtier** (réutilisation de `100LEICA`/`L1000001`) : la clé composite (date + numéro de série) évite les collisions.

## Recommendations

**Étape 1 — MVP (tri & sécurité).** Livrer d'abord le cœur du culling sûr : accès sandbox + security-scoped bookmarks ; scan DCF et regroupement des paires DNG+JPG ; grille via previews embarquées + cache disque + isolates ; visionneuse + navigation clavier ; vision obscura ; suppression avec corbeille hors-carte ; éjection propre ; garde-fous carte (dotfiles, Spotlight). *Benchmark de passage à l'étape suivante :* première rangée de vignettes < 500 ms, navigation < 100 ms, et **zéro** fichier parasite constaté sur la carte après une session complète (vérifier avec `ls -la@` sur le volume).

**Étape 2 — V1 (recadrage/export).** Mode recadrage avec ratios standard uniquement, portrait/paysage, export sur le Mac depuis la preview pleine résolution (`crop_your_image`) ; nommage et traçabilité (`crop_export`). *Seuil de bascule vers la qualité pro :* si les utilisateurs demandent des exports > 8 bits ou en Adobe RGB, passer à l'étape 4.

**Étape 3 — V1.5 (calques).** Import des 30 patterns de la Grammaire du cadre (`grammaire-du-cadre.html`), panneau calques, `CustomPainter` + poignées, persistance Drift des instances/transformations en coordonnées normalisées.

**Étape 4 — V2 (qualité pro).** Dématriçage DNG via FFI LibRaw (`flutter_libraw` ou bindings `ffigen` maison) pour exports pleine qualité ; gestion de profils couleur ; export batch. *Déclencheur :* validation préalable que `flutter_libraw` expose bien une API stable d'extraction/dématriçage (sinon, écrire les bindings LibRaw en interne).

**Décisions d'architecture à figer dès le départ :** Riverpod pour le state, Drift pour la persistance, isolates pour tout décodage, coordonnées normalisées pour les calques, clé photo composite. Ces choix évitent une dette technique coûteuse (migration hors de Hive/Isar, refonte du modèle de calques lié à la résolution d'affichage).

## Caveats

- **Dimensions exactes des previews embarquées du Q3 non confirmées par source primaire.** Il est établi que le Q3 embarque une preview JPEG pleine taille + des miniatures réduites, mais aucun dump `exiftool -a -G1` d'un DNG Q3 réel n'a pu être cité avec les valeurs pixel précises de chaque preview. **Action recommandée avant implémentation :** obtenir un DNG Q3 (ex. galerie d'échantillons DPReview) et exécuter `exiftool -a -G1 -Preview:all -ImageSize -SubfileType` pour figer les tailles réelles à cibler.
- **`flutter_libraw` est immature** (v0.0.2, « early stages », faible adoption). Ne pas en dépendre pour le MVP ; le réserver à la V2 après validation, ou prévoir des bindings FFI maison.
- **Comportement trackpad d'`InteractiveViewer`** a changé selon les versions de Flutter (3.0 → 3.3+) ; tester explicitement pinch, molette et two-finger scroll sur le matériel cible, et utiliser `trackpadPanShouldActAsZoom` si nécessaire.
- **exFAT sans journalisation** reste un risque structurel indépendant de l'app : même avec écritures atomiques, une coupure d'alimentation pendant une écriture peut corrompre le volume. Communiquer clairement à l'utilisateur qu'il ne doit jamais retirer la carte sans éjecter, et privilégier la corbeille différée (marquage) pour minimiser les écritures effectives sur la carte.
- **La fiche technique Leica** citée est la version « May 2023 » et mentionne « Subject to changes in design and production » ; des firmwares ultérieurs pourraient modifier des détails de nommage ou de preview. Revalider sur le boîtier réel de l'utilisateur.
- Les chiffres de performance (§4) sont des **objectifs cibles** à valider par profilage sur le Mac réel, non des mesures constatées.