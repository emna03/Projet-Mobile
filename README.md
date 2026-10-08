# StudyMate - Flutter

Portage Dart/Flutter du prototype StudyMate (données fictives, aucune vraie connexion ni IA).

## Lancer
```
flutter create .        # génère android/ios/web autour de lib/
flutter pub get
flutter run
```

## Structure
- lib/theme/app_theme.dart : couleurs, polices (Poppins / DM Sans), rayons, ombres
- lib/data/mock.dart : ressources, groupes, séances, questions
- lib/widgets/common.dart : carte, badge, chip, titre, recherche
- lib/screens/ : connexion, accueil, ressources (+ détail), groupes (+ détail à onglets), quiz IA (création + quiz), séances, profil
- lib/main.dart : app + barre de navigation flottante à 5 onglets
