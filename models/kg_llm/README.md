# LLM local Knowledge Map (Git LFS)

| Champ | Valeur |
| --- | --- |
| Fichier | `qwen2.5-0.5b-instruct-q4_k_m.gguf` |
| Modèle | Qwen2.5-0.5B-Instruct |
| Quant | Q4_K_M |
| Taille | ~491 Mo (491 400 032 octets) |
| Licence | Apache 2.0 |
| Transport Git | **Git LFS** (voir `.gitattributes`) |

## Récupération (camarade)

```bash
git clone <url-du-repo>
cd Projet-Mobile-Roua-Integration-Final
git checkout roua-integration
git lfs install
git lfs pull
# Vérifier le pointeur LFS → vrai fichier :
git lfs ls-files
ls -la models/kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf
flutter pub get
```

## Déploiement sur Android (chemin attendu par l’app)

`LocalModelManager` charge depuis le stockage **documents** de l’app :

`…/app_flutter/studymate_kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf`

Après `git lfs pull`, pousser **depuis ce dossier** (plus besoin de Hugging Face) :

```bat
adb push models\kg_llm\qwen2.5-0.5b-instruct-q4_k_m.gguf /data/local/tmp/qwen2.5-0.5b-instruct-q4_k_m.gguf
adb shell "run-as com.example.studymate mkdir -p app_flutter/studymate_kg_llm"
adb shell "run-as com.example.studymate cp /data/local/tmp/qwen2.5-0.5b-instruct-q4_k_m.gguf app_flutter/studymate_kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf"
```

Knowledge Graph utilise **uniquement** llama.cpp local (pas Gemini / OpenRouter).
