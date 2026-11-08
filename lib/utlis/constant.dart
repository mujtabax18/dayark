import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:metersystem/models/HomeFeatureModel.dart';
import 'package:metersystem/utlis/app_router.dart';

class ConstantStrings {
  static String mepcoURL = 'https://bill.pitc.com.pk/mepcobill';
  static String fileSavePath = '/storage/emulated/0/Download';
}

class Categories {
  static const String allDataBase = 'allDataBase';
  static const String grocery = 'Grocery';
}

class ConstantTableString {
  static String itemIn = 'In';
  static String itemOut = 'Out';
}

// You might want to move this to your constants file
const String kAppName = "Meter System";
