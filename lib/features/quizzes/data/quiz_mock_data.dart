import '../models/question.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';

class PedagogicalResource {
  const PedagogicalResource({required this.id, required this.title, required this.subject});

  final String id;
  final String title;
  final String subject;
}

const mockResources = [
  PedagogicalResource(id: 'res-spring', title: 'Cours Spring Boot', subject: 'Spring Boot'),
  PedagogicalResource(id: 'res-docker', title: 'Introduction à Docker', subject: 'Docker'),
  PedagogicalResource(id: 'res-micro', title: 'Architecture Microservices', subject: 'Microservices'),
  PedagogicalResource(id: 'res-rest', title: 'Développement API REST', subject: 'API REST'),
];

List<Question> _qs(String prefix, List<(String, List<String>, int)> items) {
  return [
    for (var i = 0; i < items.length; i++)
      Question(
        id: '$prefix-$i',
        text: items[i].$1,
        options: items[i].$2,
        correctIndex: items[i].$3,
      ),
  ];
}

final mockQuizzes = <Quiz>[
  Quiz(
    id: 'quiz-java',
    title: 'Quiz Java',
    description:
        'Révision des bases du langage Java : types, collections, POO et exceptions. Idéal pour un premier contrôle de connaissances.',
    subject: 'Java',
    difficulty: QuizDifficulty.facile,
    estimatedMinutes: 12,
    questions: _qs('java', const [
      (
        'Quel mot-clé sert à hériter d’une classe en Java ?',
        ['implements', 'extends', 'import', 'super'],
        1,
      ),
      (
        'Quelle collection garantit l’unicité des éléments ?',
        ['List', 'Set', 'Queue', 'Array'],
        1,
      ),
      (
        'Quel type primitive stocke un booléen ?',
        ['int', 'char', 'boolean', 'byte'],
        2,
      ),
      (
        'Quelle exception est non vérifiée (unchecked) ?',
        ['IOException', 'SQLException', 'NullPointerException', 'FileNotFoundException'],
        2,
      ),
      (
        'Quel modificateur rend un membre visible uniquement dans sa classe ?',
        ['public', 'protected', 'private', 'default'],
        2,
      ),
      (
        'Quelle interface représente une liste ordonnée ?',
        ['Map', 'Set', 'List', 'Iterator'],
        2,
      ),
      (
        'Que retourne `equals` pour comparer deux objets ?',
        ['int', 'boolean', 'String', 'Object'],
        1,
      ),
      (
        'Quel mot-clé empêche l’héritage d’une classe ?',
        ['static', 'final', 'abstract', 'volatile'],
        1,
      ),
      (
        'Où se trouve le point d’entrée d’une application Java ?',
        ['init()', 'start()', 'main()', 'run()'],
        2,
      ),
      (
        'Quel opérateur compare les références d’objets ?',
        ['==', 'equals', '===', 'compareTo'],
        0,
      ),
    ]),
  ),
  Quiz(
    id: 'quiz-spring',
    title: 'Quiz Spring Boot',
    description:
        'Les fondamentaux de Spring Boot : annotations, injection de dépendances, REST et configuration.',
    subject: 'Spring Boot',
    difficulty: QuizDifficulty.moyen,
    estimatedMinutes: 18,
    questions: _qs('spring', const [
      (
        'Quelle annotation démarre une application Spring Boot ?',
        ['@Component', '@SpringBootApplication', '@Bean', '@EnableAutoConfig'],
        1,
      ),
      (
        'Quelle annotation déclare un contrôleur REST ?',
        ['@Service', '@Entity', '@RestController', '@Repository'],
        2,
      ),
      (
        'Quel fichier de configuration est le plus courant ?',
        ['web.xml', 'application.properties', 'pom.boot', 'spring.ini'],
        1,
      ),
      (
        'Quelle annotation injecte une dépendance ?',
        ['@InjectValue', '@Autowired', '@Wired', '@Bind'],
        1,
      ),
      (
        'Quel starter expose une API web MVC ?',
        ['spring-boot-starter-data-jpa', 'spring-boot-starter-web', 'spring-boot-starter-test', 'spring-boot-starter-security'],
        1,
      ),
      (
        'Quelle annotation mappe une requête HTTP GET ?',
        ['@PostMapping', '@GetMapping', '@PutMapping', '@PatchMapping'],
        1,
      ),
      (
        'Où place-t-on généralement la logique métier ?',
        ['Controller', 'Service', 'Entity', 'DTO'],
        1,
      ),
      (
        'Quelle annotation marque une classe persistante JPA ?',
        ['@TableOnly', '@Entity', '@Persist', '@Model'],
        1,
      ),
      (
        'Quel port HTTP par défaut utilise Spring Boot ?',
        ['3000', '8080', '8000', '443'],
        1,
      ),
      (
        'À quoi sert `@RequestBody` ?',
        ['Lire un cookie', 'Lire le corps JSON', 'Lire un header', 'Lire un fichier'],
        1,
      ),
      (
        'Quelle annotation définit un bean dans une classe de config ?',
        ['@Bean', '@Inject', '@Value', '@Scope'],
        0,
      ),
      (
        'Quel outil simplifie le build Maven d’un projet Spring ?',
        ['webpack', 'spring initializer', 'docker compose', 'nginx'],
        1,
      ),
      (
        'Quelle couche dialogue avec la base de données ?',
        ['Controller', 'Repository', 'Filter', 'Interceptor'],
        1,
      ),
      (
        'Quel profil Spring s’active souvent en production ?',
        ['dev', 'test', 'prod', 'local'],
        2,
      ),
      (
        'Que fait `application.yml` ?',
        ['Compiler le code', 'Configurer l’application', 'Générer des DTO', 'Lancer Docker'],
        1,
      ),
    ]),
  ),
  Quiz(
    id: 'quiz-docker',
    title: 'Quiz Docker',
    description:
        'Images, conteneurs, Dockerfile et commandes essentielles pour containeriser une application.',
    subject: 'Docker',
    difficulty: QuizDifficulty.moyen,
    estimatedMinutes: 14,
    questions: _qs('docker', const [
      (
        'Quelle commande construit une image Docker ?',
        ['docker run', 'docker build', 'docker push', 'docker ps'],
        1,
      ),
      (
        'Quel fichier décrit la construction d’une image ?',
        ['Compose.yml', 'Dockerfile', 'Docker.json', 'Image.md'],
        1,
      ),
      (
        'Quelle commande liste les conteneurs en cours ?',
        ['docker images', 'docker ps', 'docker logs', 'docker rm'],
        1,
      ),
      (
        'Que fait `docker-compose up` ?',
        ['Supprime les images', 'Démarre un ensemble de services', 'Pousse vers Hub', 'Compile Java'],
        1,
      ),
      (
        'Quelle instruction définit l’image de base ?',
        ['RUN', 'FROM', 'COPY', 'CMD'],
        1,
      ),
      (
        'Quelle instruction copie des fichiers dans l’image ?',
        ['ADDONLY', 'COPY', 'MOVE', 'PUT'],
        1,
      ),
      (
        'Un conteneur isolé s’appuie principalement sur :',
        ['une VM complète', 'le noyau de l’hôte', 'un BIOS', 'un compilateur'],
        1,
      ),
      (
        'Quelle commande arrête un conteneur ?',
        ['docker kill-all', 'docker stop', 'docker end', 'docker halt'],
        1,
      ),
      (
        'À quoi sert un volume Docker ?',
        ['Limiter le CPU', 'Persister des données', 'Chiffrer le réseau', 'Compiler le code'],
        1,
      ),
      (
        'Quelle commande envoie une image vers un registre ?',
        ['docker pull', 'docker push', 'docker tag-only', 'docker export-run'],
        1,
      ),
    ]),
  ),
  Quiz(
    id: 'quiz-micro',
    title: 'Quiz Microservices',
    description:
        'Découpage en services, communication, API Gateway, résilience et observabilité.',
    subject: 'Microservices',
    difficulty: QuizDifficulty.difficile,
    estimatedMinutes: 25,
    questions: _qs('micro', const [
      (
        'Quel composant route les requêtes vers les services ?',
        ['API Gateway', 'Base de données', 'Cache unique', 'Logger'],
        0,
      ),
      (
        'Quel style de communication est synchrone ?',
        ['Kafka', 'RabbitMQ', 'HTTP REST', 'SQS'],
        2,
      ),
      (
        'Quel pattern isole une panne d’un service distant ?',
        ['Singleton', 'Circuit breaker', 'Factory', 'Observer'],
        1,
      ),
      (
        'Quelle pratique évite une base unique partagée ?',
        ['Database per service', 'Un schéma global', 'Triggers croisés', 'Jointures distantes'],
        0,
      ),
      (
        'À quoi sert le service discovery ?',
        ['Compiler les DTO', 'Trouver l’adresse des instances', 'Chiffrer les disques', 'Designer l’UI'],
        1,
      ),
      (
        'Quel problème pose un appel en chaîne trop long ?',
        ['Couplage et latence', 'Trop de RAM GPU', 'Absence de JSON', 'CSS invalide'],
        0,
      ),
      (
        'Quel outil est souvent utilisé pour le tracing distribué ?',
        ['Jaeger', 'Photoshop', 'Excel', 'Figma'],
        0,
      ),
      (
        'Quelle stratégie déploie progressivement une nouvelle version ?',
        ['Big bang', 'Canary', 'Rollback manuel seul', 'Hotfix unique'],
        1,
      ),
      (
        'Un saga sert principalement à :',
        ['Gérer une transaction métier distribuée', 'Styler une page', 'Minifier le JS', 'Créer un index SQL unique'],
        0,
      ),
      (
        'Quelle qualité vise l’idempotence d’une API ?',
        ['Même effet si l’appel est répété', 'Chiffrement AES', 'Pagination', 'Cache HTTP'],
        0,
      ),
      (
        'Le bulkhead pattern consiste à :',
        ['Isoler les ressources par groupe', 'Fusionner tous les pods', 'Désactiver TLS', 'Partager un thread unique'],
        0,
      ),
      (
        'Quel format d’événements est fréquent entre services ?',
        ['JSON', 'BMP', 'DOCX', 'MP3'],
        0,
      ),
      (
        'Pourquoi éviter les appels synchrones trop nombreux ?',
        ['Ils augmentent le couplage temporel', 'Ils accélèrent trop le CPU', 'Ils cassent Git', 'Ils bloquent DNS'],
        0,
      ),
      (
        'Un sidecar dans Kubernetes sert souvent à :',
        ['Ajouter proxy, logs ou mesh', 'Remplacer etcd', 'Compiler Java', 'Héberger l’UI'],
        0,
      ),
      (
        'Quelle métrique observe la saturation d’un service ?',
        ['Latency / errors / traffic / saturation', 'Nombre de commits', 'Taille du README', 'Couleur du logo'],
        0,
      ),
      (
        'Le BFF (Backend for Frontend) sert à :',
        ['Adapter l’API à un client précis', 'Remplacer la base', 'Générer des certificats', 'Minifier Docker'],
        0,
      ),
      (
        'Quelle approche favorise l’autonomie des équipes ?',
        ['Services découpés par domaine', 'Un monolithe unique obligatoire', 'Une équipe unique pour tout', 'Un bus UI'],
        0,
      ),
      (
        'gRPC est particulièrement adapté à :',
        ['La communication interne performante', 'Le rendu CSS', 'Les emails marketing', 'Les images PNG'],
        0,
      ),
      (
        'Un timeout trop court provoque souvent :',
        ['Des faux échecs en cascade', 'Une UI plus belle', 'Moins de logs', 'Plus de RAM GPU'],
        0,
      ),
      (
        'L’observabilité repose surtout sur :',
        ['Logs, métriques et traces', 'Un fichier Word', 'Des captures d’écran', 'Un wiki figé'],
        0,
      ),
    ]),
  ),
  Quiz(
    id: 'quiz-rest',
    title: 'Quiz API REST',
    description:
        'Verbes HTTP, codes de statut, ressources et bonnes pratiques de conception d’API.',
    subject: 'API REST',
    difficulty: QuizDifficulty.facile,
    estimatedMinutes: 15,
    questions: _qs('rest', const [
      (
        'Quel verbe HTTP sert à créer une ressource ?',
        ['GET', 'DELETE', 'PUT', 'POST'],
        3,
      ),
      (
        'Quel code signifie une création réussie ?',
        ['200', '201', '204', '400'],
        1,
      ),
      (
        'Quel verbe est censé être sans effet de bord ?',
        ['POST', 'GET', 'PATCH', 'DELETE'],
        1,
      ),
      (
        'Quel code indique une ressource introuvable ?',
        ['401', '403', '404', '500'],
        2,
      ),
      (
        'PUT est généralement :',
        ['Idempotent', 'Aléatoire', 'Réservé au HTML', 'Interdit en HTTPS'],
        0,
      ),
      (
        'Quel header décrit le type JSON ?',
        ['Accept-Language', 'Content-Type: application/json', 'Cookie', 'Host-Only'],
        1,
      ),
      (
        'Une URI REST identifie surtout :',
        ['Une ressource', 'Un fichier CSS', 'Un thread Java', 'Un conteneur'],
        0,
      ),
      (
        'Quel code indique une erreur de validation client ?',
        ['200', '301', '400', '502'],
        2,
      ),
      (
        'PATCH sert à :',
        ['Mettre à jour partiellement', 'Supprimer la collection', 'Créer un serveur', 'Lire un flux binaire'],
        0,
      ),
      (
        'HATEOAS désigne :',
        ['Des liens d’hypermédia dans les réponses', 'Un protocole SQL', 'Un type de JWT', 'Un load balancer'],
        0,
      ),
      (
        'Quel code indique un succès sans contenu ?',
        ['200', '201', '204', '304'],
        2,
      ),
      (
        'L’authentification Bearer utilise souvent :',
        ['Un jeton JWT', 'Un fichier BMP', 'Un ping ICMP', 'Un cookie Flash'],
        0,
      ),
    ]),
  ),
];

final mockHistory = <QuizResult>[
  QuizResult(
    quizId: 'quiz-java',
    quizTitle: 'Quiz Java',
    subject: 'Java',
    difficulty: QuizDifficulty.facile,
    dateLabel: '2 oct. 2026',
    correctCount: 9,
    totalCount: 10,
  ),
  QuizResult(
    quizId: 'quiz-spring',
    quizTitle: 'Quiz Spring Boot',
    subject: 'Spring Boot',
    difficulty: QuizDifficulty.moyen,
    dateLabel: '4 oct. 2026',
    correctCount: 12,
    totalCount: 15,
  ),
  QuizResult(
    quizId: 'quiz-docker',
    quizTitle: 'Quiz Docker',
    subject: 'Docker',
    difficulty: QuizDifficulty.moyen,
    dateLabel: '6 oct. 2026',
    correctCount: 7,
    totalCount: 10,
  ),
  QuizResult(
    quizId: 'quiz-micro',
    quizTitle: 'Quiz Microservices',
    subject: 'Microservices',
    difficulty: QuizDifficulty.difficile,
    dateLabel: '8 oct. 2026',
    correctCount: 17,
    totalCount: 20,
  ),
];

Quiz aiQuizFor(PedagogicalResource resource, QuizDifficulty difficulty, int count) {
  final source = mockQuizzes.firstWhere(
    (quiz) => quiz.subject == resource.subject,
    orElse: () => mockQuizzes.first,
  );
  final questions = [
    for (var i = 0; i < count; i++) source.questions[i % source.questions.length],
  ];
  return Quiz(
    id: 'quiz-ai-${resource.id}',
    title: 'Quiz IA — ${resource.subject}',
    description:
        'Quiz de démonstration généré localement à partir de « ${resource.title} ». Aucun modèle d’IA n’a été appelé.',
    subject: resource.subject,
    difficulty: difficulty,
    estimatedMinutes: (count * 1.2).round().clamp(5, 40),
    questions: questions,
    generatedByAi: true,
  );
}

List<String> get mockSubjects => [
      'Toutes',
      ...{for (final quiz in mockQuizzes) quiz.subject},
    ];
