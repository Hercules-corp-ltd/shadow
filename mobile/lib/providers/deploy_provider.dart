import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/deploy_project.dart';
import '../services/deploy_service.dart';

class DeployProvider with ChangeNotifier {
  final DeployService _service = DeployService();

  DeployProject? _project;
  double _uploadProgress = 0;
  String? _error;

  DeployProject? get project => _project;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;

  void setProject(DeployProject p) {
    _project = p;
    _uploadProgress = 0;
    _error = null;
    notifyListeners();
  }

  void updateFiles(List<DeployFile> files) {
    if (_project == null) return;
    _project = _project!.copyWith(files: files);
    notifyListeners();
  }

  Future<void> upload(
    Future<Uint8List> Function(DeployFile) readFile,
  ) async {
    if (_project == null) return;
    _project = _project!.copyWith(status: DeployStatus.uploading);
    notifyListeners();
    try {
      _project = await _service.uploadProjectFiles(
        _project!,
        readFile: readFile,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _project = _project!.copyWith(status: DeployStatus.failed);
      notifyListeners();
    }
  }

  Future<void> deploy() async {
    if (_project == null) return;
    _project = _project!.copyWith(status: DeployStatus.deploying);
    notifyListeners();
    try {
      _project = await _service.registerOnChain(_project!);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _project = _project!.copyWith(status: DeployStatus.failed);
      notifyListeners();
    }
  }

  void reset() {
    _project = null;
    _uploadProgress = 0;
    _error = null;
    notifyListeners();
  }
}
