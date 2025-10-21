// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: WorkerGenerator 7.1.7 (Squadron 7.2.0)
// **************************************************************************

import 'package:squadron/squadron.dart' as sq;

import 'data_worker_service.dart';

void _start$DataWorkerService(sq.WorkerRequest command) {
  /// VM entry point for DataWorkerService
  sq.run($DataWorkerServiceInitializer, command);
}

sq.EntryPoint $getDataWorkerServiceActivator(sq.SquadronPlatformType platform) {
  if (platform.isVm) {
    return _start$DataWorkerService;
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
