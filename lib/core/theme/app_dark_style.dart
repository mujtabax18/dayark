/// Surface treatment is independent of the accent and light/system mode.
enum AppDarkStyle {
  dim,
  black;

  static AppDarkStyle fromStorage(String? value) =>
      value == 'black' ? black : dim;
}
