
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ImgBBService {
  final String apiKey;

  ImgBBService({required this.apiKey});

  Future<String> uploadImage(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Le justificatif est introuvable.');
    }

    final uri = Uri.https(
      'api.imgbb.com',
      '/1/upload',
      {'key': apiKey},
    );

    final response = await http.post(
      uri,
      body: {
        'image': base64Encode(await file.readAsBytes()),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l’envoi vers ImgBB.');
    }

    final data = jsonDecode(response.body);

    if (data['success'] != true ||
        data['data']?['url'] == null) {
      throw Exception('ImgBB n’a pas retourné une URL valide.');
    }

    return data['data']['url'] as String;
  }
}
