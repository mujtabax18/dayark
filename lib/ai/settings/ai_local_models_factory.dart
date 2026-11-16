import 'ai_local_models.dart';
import 'ai_local_models_stub.dart'
    if (dart.library.io) 'ai_local_models_native.dart'
    as platform;

Future<AiLocalModels> sharedAiLocalModels() => platform.sharedAiLocalModels();
