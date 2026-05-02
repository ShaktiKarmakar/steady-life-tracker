/// Alignment notes: Google “LLM Inference guide for iOS” (MediaPipeTasksGenAI,
/// bundled models, Kaggle examples) vs Steady’s Flutter + `flutter_gemma` stack.
///
/// ### Decision: bundle vs HTTPS download (todo: bundle-vs-download)
///
/// Google’s **native** quickstart adds `MediaPipeTasksGenAI` pods and ships weights
/// inside the app bundle (`Bundle.main.path(forResource:ofType:)`), often after
/// downloading from **Kaggle** once during development—not at runtime for end users.
///
/// **Steady keeps runtime HTTPS download** (default Hugging Face URL, anonymous-first,
/// optional Hugging Face read token, optional `STEADY_MODEL_MIRROR_URL` define) so the
/// App Store / Play binary stays small and weights update without resubmitting the
/// whole app when you change hosting strategy.
///
/// **Bundling like Google’s doc (optional):** add the `.task` file under `flutter`
/// `assets`, declare it in [pubspec.yaml], then use `FlutterGemma.installModel(...)`
/// `.fromAsset(...)` per `flutter_gemma` docs. Trade-off: multi‑hundred‑MB store
/// download and slower installs.
///
/// ### LiteRT-LM / deprecation evaluation (todo: litertlm-migration)
///
/// Google notes classic MediaPipe LLM Inference is **deprecated** in favor of
/// **LiteRT-LM**. In `flutter_gemma`, `.litertlm` uses [ModelFileType.litertlm] and
/// the LiteRT FFI path on mobile where applicable.
///
/// **Default checkpoint:** `litert-community/gemma-4-E2B-it-litert-lm` —
/// `gemma-4-E2B-it.litertlm` + [ModelType.gemma4] + [ModelFileType.litertlm]. Legacy
/// Gemma 3 1B `.task` + [ModelType.gemmaIt] was replaced after LiteRT-LM QA.
///
/// Migrating to another `.litertlm` still requires: matching URL + [ModelType],
/// install checks, onboarding copy, and **regression on physical iOS and Android**.
library;

/// Anchor for doc discovery (`dart doc` / IDE). Not used at runtime.
abstract final class EdgeAiAlignmentNotes {
  EdgeAiAlignmentNotes._();
}
