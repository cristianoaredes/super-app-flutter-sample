import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

/// Ensures [HydratedBloc.storage] exists on every target, including web.
///
/// Official hydrated_bloc 9.x pattern: web uses
/// [HydratedStorage.webStorageDirectory]; IO uses a temp directory.
/// Safe to call more than once — returns immediately if storage is already set.
Future<void> ensureHydratedStorage() async {
  try {
    HydratedBloc.storage;
    return;
  } on StorageNotFound {
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: kIsWeb
          ? HydratedStorage.webStorageDirectory
          : Directory.systemTemp.createTempSync('hydrated_bloc'),
    );
  }
}
