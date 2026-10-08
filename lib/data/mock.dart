class Resource {
  final String id, title, subject, author, visibility;
  final bool free;
  final int pages;
  const Resource(this.id, this.title, this.subject, this.author, this.free, this.visibility, this.pages);

  Resource copyWith({
    String? title,
    String? subject,
    String? author,
    bool? free,
    String? visibility,
    int? pages,
  }) =>
      Resource(id, title ?? this.title, subject ?? this.subject, author ?? this.author, free ?? this.free,
          visibility ?? this.visibility, pages ?? this.pages);
}

class Group {
  final String id, name, level;
  final int members, max;
  final bool public;
  const Group(this.id, this.name, this.level, this.members, this.max, this.public);

  Group copyWith({String? name, String? level, int? members, int? max, bool? public}) =>
      Group(id, name ?? this.name, level ?? this.level, members ?? this.members, max ?? this.max, public ?? this.public);
}

class Session {
  final String id, subject, date, time, mode;
  final int price, seats, seatsLeft;
  final bool booked;
  const Session(this.id, this.subject, this.date, this.time, this.mode, this.price, this.seats, this.seatsLeft, this.booked);

  Session copyWith({
    String? subject,
    String? date,
    String? time,
    String? mode,
    int? price,
    int? seats,
    int? seatsLeft,
    bool? booked,
  }) =>
      Session(id, subject ?? this.subject, date ?? this.date, time ?? this.time, mode ?? this.mode, price ?? this.price,
          seats ?? this.seats, seatsLeft ?? this.seatsLeft, booked ?? this.booked);
}

class Question {
  final String text;
  final List<String> answers;
  final int correct;
  const Question(this.text, this.answers, this.correct);
}

const resources = [
  Resource('r1', 'Spring Boot : les bases', 'Spring Boot', 'Sarah Ben Ali', true, 'Public', 24),
  Resource('r2', 'Docker en pratique', 'Docker', 'Yassine Trabelsi', true, 'Groupe', 18),
  Resource('r3', 'Architecture microservices', 'Microservices', 'Ines Haddad', false, 'Public', 42),
  Resource('r4', 'Concevoir une API REST', 'REST', 'Karim Mansour', true, 'Privé', 15),
];

const groups = [
  Group('g1', 'Spring Boot Masters', 'Licence 3', 6, 10, true),
  Group('g2', 'Docker & DevOps', 'Master 1', 8, 10, true),
  Group('g3', 'API REST avancées', 'Licence 2', 4, 8, false),
];

const sessions = [
  Session('s1', 'Docker', 'Jeu. 8 oct.', '18:00', 'En ligne', 0, 12, 5, true),
  Session('s2', 'Spring Boot', 'Sam. 10 oct.', '10:00', 'Présentiel', 15, 8, 3, false),
  Session('s3', 'Microservices', 'Lun. 12 oct.', '19:30', 'En ligne', 10, 20, 11, false),
];

const questions = [
  Question('Quelle commande construit une image Docker ?',
      ['docker run', 'docker build', 'docker push', 'docker ps'], 1),
  Question('Quelle annotation déclare un contrôleur REST dans Spring Boot ?',
      ['@Service', '@Entity', '@RestController', '@Bean'], 2),
  Question('Quel verbe HTTP sert à créer une ressource ?',
      ['GET', 'DELETE', 'PUT', 'POST'], 3),
  Question('Quel composant route les requêtes vers les microservices ?',
      ['API Gateway', 'Base de données', 'Cache', 'Logger'], 0),
];
