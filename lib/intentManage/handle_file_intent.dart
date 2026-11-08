import 'package:metersystem/intentManage/managehousejson.dart';

import '../utlis/helper_functions.dart';

Future<void> handleFile(String filePath) async {
  final String? extension = getFileExtension(filePath);

  if (extension == null) {
    print("No file extension found.");
    return;
  }

  switch (extension) {
    case '.txt':
      print("This is a text file: $filePath");
      // Handle text file
      break;
    case '.jpg':
    case '.jpeg':
    case '.png':
      print("This is an image file: $filePath");
      // Handle image file
      break;
    case '.pdf':
      print("This is a PDF file: $filePath");
      // Handle PDF file
      break;
    case '.housejson':
      await manageHouseJson(filePath);
      // Handle PDF file
      break;
    default:
      print("Unsupported file type: $extension");
    // Handle unsupported file types
  }
}
