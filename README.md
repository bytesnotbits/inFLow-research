# inFLow-research

## Normalizing the Legacy CSV Exports

1. Drop the cleaned inFlow exports into `inflow_web/db/original_exports`.
2. Run the builder to generate the normalized database snapshot:
   ```
   dart run inflow_web/bin/normalize_data.dart
   ```
   (If `dart` is not on your path, use `flutter pub run inflow_web/bin/normalize_data.dart`.)
3. The script writes `inflow_web/db/normalized/normalized_database.json` plus a summary of how many rows mapped for each dataset. The Flutter app can load this JSON instead of reparsing the raw CSVs on every launch.
