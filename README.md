# inFLow-research

## Normalizing the Legacy CSV Exports

1. Drop the cleaned inFlow exports into `inflow_web/db/original_exports`.
2. Run the builder to generate the normalized database snapshot:
   ```
   dart run inflow_web/bin/normalize_data.dart
   ```
   (If `dart` is not on your path, use `flutter pub run inflow_web/bin/normalize_data.dart`.)
3. The script writes `inflow_web/db/normalized/normalized_database.json` and logs how many rows mapped for each dataset. Copy that JSON file to your internal shared drive (or any other secure location) so the web app can load it at runtime instead of bundling sensitive data in this public repo.
4. Update the `_dataShareLocationHint` constant in `inflow_web/lib/main.dart` or provide `--dart-define=INFLOW_DATA_SHARE_PATH=\\\\server\\share\\path\\normalized_database.json` when building so users see the correct network path inside the UI.

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

### Runtime snapshot selection

The web client no longer ships with a baked-in dataset. When the page loads it prompts the user to select the latest `normalized_database.json` from the shared drive path you configure (see `INFLOW_DATA_SHARE_PATH`). Once selected, the familiar “large file” loading modal appears while the snapshot is parsed, and the workspace behaves exactly like before. Users can still import additional CSV/XLSX files at any time via the **Import Files** button.
