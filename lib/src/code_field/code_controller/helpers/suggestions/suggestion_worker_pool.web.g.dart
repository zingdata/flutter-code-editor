// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: WorkerGenerator 7.1.7 (Squadron 7.2.0)
// **************************************************************************

import 'package:squadron/squadron.dart' as sq;

import 'suggestion_worker_pool.dart';

void main() {
  /// Web entry point for SuggestionWorkerPool
  sq.run($SuggestionWorkerPoolInitializer);
}

sq.EntryPoint $getSuggestionWorkerPoolActivator(
    sq.SquadronPlatformType platform) {
  if (platform.isWeb) {
    return sq.Squadron.uri('~/workers/suggestion_worker_pool.web.g.dart.js');
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
