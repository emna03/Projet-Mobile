# LLM local — My Knowledge Map

## Modèle

| Champ | Valeur |
| --- | --- |
| Nom | **Qwen2.5-0.5B-Instruct** |
| Paramètres | 0.5B |
| Quantification | **Q4_K_M** (GGUF) |
| Taille | ~491 Mo (491 400 032 octets) |
| Licence | Apache 2.0 |
| Moteur | llama.cpp via `llama_flutter_android` |
| Dans le dépôt | `models/kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf` via **Git LFS** |

## Pour un membre de l’équipe (branche `roua-integration`)

1. Prérequis : [Git LFS](https://git-lfs.com) installé (`git lfs version`).
2. Cloner / basculer sur la branche, puis tirer le binaire LFS :

```bash
git checkout roua-integration
git lfs install
git lfs pull
git lfs ls-files
# Doit lister : models/kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf
flutter pub get
```

3. Installer le GGUF **dans le chemin runtime Android** (l’app ne lit pas le dossier Git sur le téléphone) :

```bat
adb push models\kg_llm\qwen2.5-0.5b-instruct-q4_k_m.gguf /data/local/tmp/qwen2.5-0.5b-instruct-q4_k_m.gguf
adb shell "run-as com.example.studymate mkdir -p app_flutter/studymate_kg_llm"
adb shell "run-as com.example.studymate cp /data/local/tmp/qwen2.5-0.5b-instruct-q4_k_m.gguf app_flutter/studymate_kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf"
```

Chemin attendu par `LocalModelManager` :

`/data/user/0/com.example.studymate/app_flutter/studymate_kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf`

Aucun téléchargement Hugging Face n’est requis si `git lfs pull` a réussi.

## Installation manuelle (secours sans LFS)

1. Télécharger :
   `https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf`
2. Placer sous `models/kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf`
3. Puis même `adb push` / `run-as cp` que ci-dessus.

## Comportement

- **✨ Enrichir** : LLM local si le GGUF est présent dans le stockage app ; sinon message « modèle absent ».
- Échec d’inférence / JSON invalide → **heuristique** (jamais présentée comme LLM).
- **Aucun** appel Gemini / OpenRouter depuis Knowledge Graph.
