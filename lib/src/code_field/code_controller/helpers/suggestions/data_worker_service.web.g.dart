// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: WorkerGenerator 7.1.7 (Squadron 7.2.0)
// **************************************************************************

import 'package:squadron/squadron.dart' as sq;

import 'data_worker_service.dart';

void main() {
  /// Web entry point for DataWorkerService
  sq.run($DataWorkerServiceInitializer);
}

sq.EntryPoint $getDataWorkerServiceActivator(sq.SquadronPlatformType platform) {
  if (platform.isWeb) {
    return sq.Squadron.uri('~/workers/data_worker_service.web.g.dart.js');
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
