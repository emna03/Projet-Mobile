# StudyMate

**StudyMate** est une application mobile (Flutter) de **révision collaborative** pour étudiants et enseignants. L'idée : réunir au même endroit tout ce qu'il faut pour réviser ensemble. On y retrouve ses cours, ses groupes d'étude, des quiz qui s'adaptent à son niveau, et des séances de révision planifiées avec les bons participants, au bon moment, sans conflit d'horaire.

## Sommaire
- [Fonctionnalités](#fonctionnalités)
- [Technologies](#technologies)
- [Architecture du projet](#architecture-du-projet)
- [Installation et lancement](#installation-et-lancement)
- [Configuration des services externes](#configuration-des-services-externes)
- [Tests](#tests)
- [Données de démonstration](#données-de-démonstration)
- [Équipe](#équipe)

## Fonctionnalités

L'application est organisée en modules, un par onglet de la barre de navigation (Accueil, Ressources, Groupes, Séances, Profil).

### Utilisateurs et authentification
- Inscription étudiant ou enseignant, connexion par e-mail (compte vérifié) ou Google, mot de passe oublié.
- **Vérification des enseignants** : le justificatif est analysé par OCR (ML Kit) avant validation.
- **Verrouillage biométrique** (empreinte) activable par l'utilisateur.
- Profil modifiable, avec photo.

### Ressources
- Ajout de cours (texte ou fichier) avec matière, auteur et visibilité.
- **Résumés et flashcards générés par IA** (Google Gemini) à partir du cours.

### Groupes d'étude et chat
- Création de groupes, filtres, demandes d'adhésion à valider par le responsable.
- **Assistant IA** pour rédiger la description d'un groupe, et **suggestions de livres** (Google Books).
- Chat de groupe : messages, pièces jointes, réactions et **sondages**.

### Quiz et carte des connaissances
- Quiz dont la difficulté s'adapte aux résultats.
- **Carte des connaissances** : les questions sont reliées à des concepts, le niveau de maîtrise de chaque concept est calculé, et l'application recommande quoi réviser ensuite.
- Un petit modèle de langage **local** (Qwen2.5-0.5B, via llama.cpp) enrichit la carte sans connexion à un service externe.

### Séances de révision
Proposer, trouver et suivre des séances de révision.
- **Proposer et réserver** des séances en ligne ou en présentiel, avec places limitées. Seul l'organisateur peut modifier ou supprimer sa séance.
- **Google Meet** : création du lien de la salle depuis l'application, changement du type d'accès, fin de la réunion en cours, gestion des invités.
- **Google Agenda** : ajout d'une séance à son calendrier, mise à jour ou suppression automatique, et page « Mon agenda » qui affiche les événements Google avec les séances réservées.
- **Créneaux communs** : chaque participant indique ses plages libres de la semaine ; l'application propose les créneaux où tout le monde est disponible, ou les meilleurs compromis.
- **Détection des conflits d'horaires** : deux séances au même moment, un participant indisponible, ou un événement de l'agenda qui chevauche. L'utilisateur est averti et peut confirmer.
- **Météo** : pour une séance en présentiel, la météo au début et à la fin de la séance (Open-Meteo), avec un conseil si besoin.
- **Rappels** : notification 30 minutes avant chaque séance proposée ou réservée, et panneau de notifications.

## Technologies

| Domaine | Outils |
|---|---|
| Application | Flutter / Dart (SDK `^3.13.4`) |
| Authentification et données partagées | Firebase Auth, Cloud Firestore, Google Sign-In |
| Données locales | SQLite (`sqflite`) |
| Sécurité | `local_auth` (biométrie), `flutter_secure_storage` |
| Reconnaissance de texte | `google_mlkit_text_recognition` |
| IA | Google Gemini (`firebase_ai`), llama.cpp (`llama_flutter_android`) |
| Google | API Google Meet, Google Agenda, Google Books |
| Météo | Open-Meteo (sans clé d'API) |
| Notifications | `flutter_local_notifications` |

## Architecture du projet

Le code est organisé **par fonctionnalité** : chaque module regroupe ses modèles, ses services, ses écrans et son stockage.

```
lib/
├── main.dart                  Point d'entrée, connexion et navigation
├── core/                      Thème, widgets communs, services partagés, configuration
└── features/
    ├── gestion_user/          Inscription, connexion, profil, OCR, biométrie
    ├── home/                  Accueil
    ├── resources/             Cours, résumés et flashcards IA
    ├── groups/                Groupes d'étude, livres, assistant de description
    ├── group_chat/            Messages, pièces jointes, sondages
    ├── quizzes/               Quiz et carte des connaissances
    ├── seances/               Séances : liste, formulaire, stockage
    ├── availability/          Disponibilités et créneaux communs
    ├── conflicts/             Détection des conflits d'horaires
    ├── calendar/              Google Agenda et page « Mon agenda »
    ├── meet/                  Google Meet
    ├── weather/               Météo d'une séance en présentiel
    └── notifications/         Rappels et notifications
```

Chaque module est développé sur sa propre branche, puis intégré dans `main`.

## Installation et lancement

### Prérequis
- [Flutter](https://docs.flutter.dev/get-started/install) 3.47 ou plus récent (Dart `^3.13.4`)
- Android Studio avec le SDK Android et un JDK 17
- Un téléphone Android (débogage USB ou sans fil activé) ou un émulateur
- [Git LFS](https://git-lfs.com), seulement pour le modèle de langage local des quiz

### Lancer l'application
```bash
git clone https://github.com/emna03/Projet-Mobile.git
cd Projet-Mobile
flutter pub get
flutter run
```

Pour créer un APK de test :
```bash
flutter build apk --debug
```

## Configuration des services externes

Le fichier de configuration Firebase est déjà dans le dépôt. Plusieurs services demandent une configuration supplémentaire sur ta machine.

**Connexion Google, Google Meet et Google Agenda**
1. Récupère l'empreinte SHA-1 de ta clé de debug :
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   ```
2. Ajoute-la dans la console Firebase (Paramètres du projet, application Android). Sans elle, Google refuse la connexion.
3. Dans Google Cloud (même projet), active l'API **Google Meet REST** et l'API **Google Calendar**, et déclare les niveaux d'accès `meetings.space.created` et `calendar.events`.
4. Ces niveaux d'accès sont sensibles : tant que l'application n'est pas validée par Google, un écran « application non validée » s'affiche à la première connexion (« Avancé », puis continuer).

**Clés d'API (facultatives)**

Les clés ne doivent jamais être écrites dans le code. Crée un fichier `dart_defines.json` à la racine (il est ignoré par Git) :
```json
{
  "GEMINI_API_KEY": "ta-clé",
  "IMGBB_API_KEY": "ta-clé"
}
```
puis lance l'application avec :
```bash
flutter run --dart-define-from-file=dart_defines.json
```
Sans clé Gemini, l'application utilise Gemini via Firebase si le projet est configuré.

**Modèle de langage local (quiz)**

Le fichier `models/kg_llm/qwen2.5-0.5b-instruct-q4_k_m.gguf` (environ 491 Mo) est stocké avec Git LFS :
```bash
git lfs install
git lfs pull
```
Le guide d'installation sur le téléphone est dans `lib/features/quizzes/knowledge_graph/services/local_llm/MODEL_INSTALL.md`.

La météo (Open-Meteo) et Google Books ne demandent aucune clé.

## Tests

```bash
flutter analyze
flutter test
```

Les tests couvrent notamment les appels aux API Google et à la météo (réponses simulées), le calcul des créneaux communs, la détection des conflits, les rappels, et la carte des connaissances.

## Données de démonstration

Pour essayer les séances sans rien saisir, ouvre l'onglet **Séances** et touche **« Charger des séances d'exemple (test) »** en bas de la liste. Cela ajoute cinq séances à venir et quatre participants fictifs (Sarah Ben Ali, Yassine Trabelsi, Ines Gharbi, Amine Khaled) avec leurs disponibilités. Une des séances chevauche volontairement une autre, pour montrer la détection de conflit.

Ces participants **ne sont pas des comptes de connexion** : ils n'existent que dans la base locale du téléphone. Le même bouton devient **« Supprimer les séances d'exemple »** pour tout effacer sans toucher à tes vraies données.

## Équipe

Projet réalisé en équipe. Contributeurs au dépôt : emna03, nacef20, aminebarrani, Rouamessoudi, ILYES et wolftn14-droid.
