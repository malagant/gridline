import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

/// Dateidialoge. Auf iOS gibt es keinen Speichern-Dialog, dort landen Projekte
/// und Exporte im Dokumente-Ordner der App (über die Dateien-App sichtbar).
abstract final class Files {
  static const _wav = XTypeGroup(label: 'WAV', extensions: ['wav'], uniformTypeIdentifiers: ['com.microsoft.waveform-audio']);
  static const _project = XTypeGroup(label: 'Gridline-Projekt', extensions: ['gridline'], uniformTypeIdentifiers: ['public.json', 'public.data']);

  static bool get _mobile => Platform.isIOS || Platform.isAndroid;

  static Future<String?> pickSample() async => (await openFile(acceptedTypeGroups: [_wav]))?.path;

  static Future<String?> pickProject() async => (await openFile(acceptedTypeGroups: [_project]))?.path;

  static Future<String?> saveProject() => _saveLocation('song.gridline', _project);

  static Future<String?> saveWav() => _saveLocation('gridline-export.wav', _wav);

  static Future<String?> _saveLocation(String name, XTypeGroup group) async {
    if (_mobile) {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$name';
    }
    return (await getSaveLocation(suggestedName: name, acceptedTypeGroups: [group]))?.path;
  }
}
