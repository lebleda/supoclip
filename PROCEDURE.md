# PROCEDURE — Nommage des clips générés

> **Règle à respecter à TOUTE prochaine génération de clip.**
> Les clips ne portent plus de nom générique (`clip_1_0225_abc123.mp4`).
> Chaque clip est nommé par **un bloc : titre de vidéo — description — tags**, suivi d'un suffixe technique.

## 0. Destination des livrables (consigne utilisateur 2026-10-08)

Dès le 2026-10-08, les clips générés + leur `.txt` (TITLE/DESCRIPTION/TAGS) sont déposés dans :

```
C:\Users\katib\OneDrive\Desktop\CLIPS PHONE\
```

(Le dossier historique `...\OneDrive\Desktop\clippers\` concerne les vidéos antérieures.)

## 1. Format du nom de fichier (obligatoire)

```
<Titre du clip> - <Description courte> #tag1 #tag2 #tag3_<n>_<MMSS>_<date>_<hex>.mp4
```

Exemple réel :

```
The $40k mistake I keep seeing - A founder explains how he lost 40k on a bad hire #startup-advice #hiring-tip_1_0225_10081237_d247.mp4
```

| Bloc | Source | Règle |
|---|---|---|
| **Titre** | champ IA `seo_title` (fallback : `hook_title`, puis extrait du texte) | 4–12 mots, max 100 car., lisible et cherchable, texte brut (espaces) |
| **Description** | champ IA `seo_description` | 1 phrase, max 200 car., ancrée dans le contenu du clip |
| **Tags** | champ IA `seo_tags` | 3–8 mots-clés minuscules ; émis en hashtags hyphénés (`startup advice` → `#startup-advice`) |
| **Suffixe technique** | calculé | `<ordre>_<start MMSS>_<MMDDHHMM>_<hex4>` — garantit l'unicité et l'ordre |

Contraintes :

- Caractères interdits (nettoyés automatiquement) : `\ / : * ? " < > |`
- Longueur totale du bloc : **≤ 160 caractères** avant suffixe. Limite réelle : le
  sidecar `<clip>.source_map.json` ajoute 16 car. + suffixe ~21 + répertoires de
  rendu (~60) → tout doit rester sous **MAX_PATH Windows (260)**
- Priorité si ça déborde : **titre complet → tous les tags → description rognée
  au mot** (jamais au milieu d'un mot ; < 20 car. restantes → description omise)
- Pas de hashtags ni emojis dans le titre/description **stockés** (les `#` n'existent que pour les tags émis dans le nom)
- Le nom ne casse rien côté web : les clips sont **servis par id UUID** (`/tasks/{id}/clips/{clip_id}/file`), et le front encode avec `encodeURIComponent` — jamais de concaténation brute du filename dans une URL

## 2. Métadonnées IA (générées à chaque analyse)

Chaque segment renvoyé par l'analyse LLM (`backend/src/ai.py`) contient :

- `seo_title` — titre permanent du clip (≠ `hook_title`, qui est le texte brûlé à l'écran)
- `seo_description` — une phrase de description
- `seo_tags` — liste de mots-clés

Sanitisers appliqués avant validation : `sanitize_seo_title()`, `sanitize_seo_description()`, `sanitize_seo_tags()`
dans `backend/src/ai.py`. Le constructeur du nom est **`build_clip_filename_block()`** (même fichier).

Le prompt système (`transcript_analysis_system_prompt` + `build_transcript_analysis_prompt`)
exige ces trois champs ; `TRANSCRIPT_ANALYSIS_CACHE_VERSION = "seo-filename-block-v6"`
invalide les vieux caches d'analyse pour forcer la régénération avec les champs SEO.

## 3. Points d'implémentation (ne pas régresser)

| Fichier | Rôle |
|---|---|
| `backend/src/ai.py` | Champs `seo_*` du modèle Pydantic, prompt, sanitizers, `build_clip_filename_block()` |
| `backend/src/services/video_service.py` | `create_single_clip()` : construit le nom via `build_clip_filename_block()` (chemin principal) |
| `backend/src/video_utils.py` | `create_clips_with_transitions()` : même nommage (chemin régénération) |
| `backend/src/services/task_service.py` | Persiste `seo_title/seo_description/seo_tags` dans `generated_clips` |
| `backend/src/services/clip_service.py` | Régénération et split reportent les champs SEO |
| `backend/src/services/editor_service.py` | `combine_editor` : nom dérivé du clip source + métadonnées conservées |
| `backend/src/clip_editor.py` | `derive_clip_name()` : trim/split/merge/captions/export **conservent le bloc SEO** du fichier source |
| `backend/src/repositories/clip_repository.py` | INSERT/SELECT `seo_*` (tolère les anciennes BDD via fallback SQLSTATE 42703) |
| `init.sql` | Colonnes `seo_title`, `seo_description`, `seo_tags` sur `generated_clips` (install neuve) |
| `backend/src/migrations/sql/20261008_0001_clip_seo_filename_fields.sql` | Même colonnes sur une base existante (auto-appliquée au démarrage de l'API) |
| `mcp/src/supoclip_mcp/server.py` | `_safe_filename()` préserve le bloc ; le nom par défaut d'un téléchargement MCP redevient le fichier généré du clip |

## 4. Migration pour une base existante

- **Install neuve** : `init.sql` crée déjà les colonnes.
- **Base existante** : la migration `backend/src/migrations/sql/20261008_0001_clip_seo_filename_fields.sql`
  s'applique **automatiquement au démarrage de l'API** (`init_db()` dans `backend/src/database.py`,
  suivi de `schema_migrations`). Aucune action manuelle.

Manuellement, l'équivalent est :

```sql
ALTER TABLE generated_clips
    ADD COLUMN IF NOT EXISTS seo_title VARCHAR(120),
    ADD COLUMN IF NOT EXISTS seo_description VARCHAR(250),
    ADD COLUMN IF NOT EXISTS seo_tags TEXT;
```

Sans cette alteration, le code fonctionne quand même (fallback 42703) : les clips seront
bien nommés en bloc, mais les métadonnées `seo_*` ne seront pas stockées en BDD.

### Renommer des clips déjà générés (si le format évolue)

Renommer **les trois** : le `.mp4`, son sidecar `<même basename>.source_map.json`
(obligatoire, sinon éditeur/resume casse), et BDD `generated_clips` :
`UPDATE generated_clips SET filename=<new>, file_path=<chemin> WHERE id=...`
(`file_path` contient le nom). Garder le suffixe technique `_n_MMSS_MMDDHHMM_hex4`
d'origine. Script de référence : `C:\Users\katib\AppData\Local\Temp\opencode\ay-rename.py`.

## 5. Checklist des prochaines générations

Avant de livrer toute évolution du pipeline de clipping :

1. [ ] Le fichier exporté commence par le **titre** du clip, pas par `clip_`
2. [ ] Le bloc contient **titre + description + tags** dans cet ordre, séparés par ` - ` et ` `
3. [ ] Aucun caractère interdit pour le filesystem ne subsiste
4. [ ] Les éditions (trim, split, merge, captions, export preset, combine) conservent le nom source
5. [ ] `seo_title`, `seo_description`, `seo_tags` sont persistés dans `generated_clips`
6. [ ] Le front affiche / télécharge le clip sans URL cassée (encodage OK)
7. [ ] Le prompt IA exige toujours les 3 champs et le cache d'analyse est invalidé si le contrat change

## 6. Test rapide

```bash
cd backend && PYTHONPATH=. .venv/bin/python - <<'PY'
from src.ai import build_clip_filename_block
print(build_clip_filename_block(
    "The $40k mistake I keep seeing",
    "A founder explains how he lost 40k on a bad hire",
    ["startup advice", "hiring tip"], clip_index=0, start_time="02:25",
    fallback_title="Why nobody tells you this about VC",
) + ".mp4")
PY
```

Sortie attendue : un nom commençant par `The $40k mistake ...`, contenant
` #startup-advice #hiring-tip`, sans `clip_`, sans caractère interdit.
