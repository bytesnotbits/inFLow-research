# inFLow-research

## Normalizing the Legacy CSV Exports

1. Drop the cleaned inFlow exports into `inflow_web/db/original_exports`.
2. Run the builder to generate the normalized database snapshot:
   ```
   dart run inflow_web/bin/normalize_data.dart
   ```
   (If `dart` is not on your path, use `flutter pub run inflow_web/bin/normalize_data.dart`.)
3. The script writes `inflow_web/db/normalized/normalized_database.json`, copies the same snapshot into `inflow_web/assets/normalized/normalized_database.json`, and logs how many rows mapped for each dataset. The Flutter app loads the asset copy automatically, so you no longer need to re-import the raw CSVs every session.
