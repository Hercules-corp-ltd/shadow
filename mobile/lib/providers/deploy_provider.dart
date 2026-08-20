import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/deploy_project.dart';
import '../services/deploy_service.dart';
import '../services/fetch_outcome.dart';

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
    // Cleared on entry so Retry does not run under the previous message.
    _error = null;
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
      // The progress screen renders this verbatim on its failure card, and
      // everything here reaches the network through Dio — so this was a
      // multi-line debug dump, request URI and stack trace included, shown to
      // a user as the explanation of what went wrong.
      _error = e is DioException
          ? describeDioFailure(e)
          : 'The upload could not be completed.';
      _project = _project!.copyWith(status: DeployStatus.failed);
      notifyListeners();
    }
  }

  Future<void> deploy() async {
    if (_project == null) return;
    _error = null;
    _project = _project!.copyWith(status: DeployStatus.deploying);
    notifyListeners();
    try {
      _project = await _service.registerOnChain(_project!);
      notifyListeners();
    } catch (e) {
      _error = e is DioException
          ? describeDioFailure(e)
          : 'The site could not be registered.';
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
