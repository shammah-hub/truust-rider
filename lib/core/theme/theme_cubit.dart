import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Controls app-wide theme mode (light / dark / system).
/// Place at: lib/core/theme/theme_cubit.dart
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  void toggle() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setDark() => emit(ThemeMode.dark);
  void setLight() => emit(ThemeMode.light);
  void setSystem() => emit(ThemeMode.system);
}
