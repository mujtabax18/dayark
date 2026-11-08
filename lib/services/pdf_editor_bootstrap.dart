import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';

/// Call this once in main(), before runApp().
///
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   initializePdfEditorAssets();
///   runApp(const MyApp());
/// }
void initializePdfEditorAssets() {
  registerBundledEditorAssets();
}
