# inFLow-research

## Normalizing the Legacy CSV Exports

1. Drop the cleaned inFlow exports into `inflow_web/db/original_exports`.
2. Run the builder to generate the normalized database snapshot:
   ```
   dart run inflow_web/bin/normalize_data.dart
   ```
   (If `dart` is not on your path, use `flutter pub run inflow_web/bin/normalize_data.dart`.)
3. The script writes `inflow_web/db/normalized/normalized_database.json`, copies the same snapshot into `inflow_web/assets/normalized/normalized_database.json`, and logs how many rows mapped for each dataset. The Flutter app loads the asset copy automatically, so you no longer need to re-import the raw CSVs every session.

## Deploying the Flutter Web App to GitHub Pages

The repository ships with a workflow (`.github/workflows/deploy-gh-pages.yml`) that rebuilds the Flutter web client and pushes the output to a `gh-pages` branch when it runs.

1. Push (or merge) to `main` or trigger the workflow manually from the **Actions → Deploy Flutter Web** tab.
2. After the first successful run, open **Settings → Pages** and set the source to **Deploy from a branch → gh-pages / (root)** so GitHub Pages serves the static Flutter build. Give GitHub ~1 minute to refresh after each deployment.

### Manual preview / debugging

To inspect the bundle locally, run the same build command that the workflow uses:

```
cd inflow_web
flutter build web --release --base-href /inFLow-research/
```

Then serve the contents of `inflow_web/build/web` with any static web server (for example, `python3 -m http.server 8080`).
