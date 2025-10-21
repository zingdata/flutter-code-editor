// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: WorkerGenerator 7.1.7 (Squadron 7.2.0)
// **************************************************************************

import 'package:squadron/squadron.dart' as sq;

import 'suggestion_worker_pool.dart';

void _start$SuggestionWorkerPool(sq.WorkerRequest command) {
  /// VM entry point for SuggestionWorkerPool
  sq.run($SuggestionWorkerPoolInitializer, command);
}

sq.EntryPoint $getSuggestionWorkerPoolActivator(
    sq.SquadronPlatformType platform) {
  if (platform.isVm) {
    return _start$SuggestionWorkerPool;
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
