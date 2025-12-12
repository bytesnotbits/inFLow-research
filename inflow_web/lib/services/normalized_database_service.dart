import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/normalized_database.dart';

class NormalizedDatabaseService {
  const NormalizedDatabaseService({
    this.assetPath = defaultAssetPath,
  });

  final String assetPath;

  static const String defaultAssetPath =
      'assets/normalized/normalized_database.json';

  Future<NormalizedDatabase?> load() async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      if (jsonString.isEmpty) return null;
      final payload = json.decode(jsonString) as Map<String, dynamic>;
      return NormalizedDatabase.fromJson(payload);
    } catch (error, stackTrace) {
      debugPrint(
        'NormalizedDatabaseService: unable to load $assetPath — $error\n$stackTrace',
      );
      return null;
    }
  }
}
