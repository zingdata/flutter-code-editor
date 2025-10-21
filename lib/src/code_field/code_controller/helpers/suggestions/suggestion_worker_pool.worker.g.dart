// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suggestion_worker_pool.dart';

// **************************************************************************
// Generator: WorkerGenerator 7.1.7 (Squadron 7.2.0)
// **************************************************************************

/// Command ids used in operations map
const int _$decodeJsonId = 1;
const int _$encodeJsonId = 2;
const int _$performHeavyComputationId = 3;
const int _$processLargeDataSetId = 4;
const int _$processSqlSuggestionItemsId = 5;
const int _$processSuggestionsId = 6;
const int _$processTableChunkId = 7;
const int _$processWithProgressId = 8;
const int _$validateDataId = 9;

/// WorkerService operations for SuggestionWorkerPool
extension on SuggestionWorkerPool {
  sq.OperationsMap _$getOperations() => sq.OperationsMap({
        _$decodeJsonId: ($req) async {
          final dynamic $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await decodeJson($dsr.$0($req.args[0]));
          } finally {}
          return $res;
        },
        _$encodeJsonId: ($req) => encodeJson($req.args[0]),
        _$performHeavyComputationId: ($req) async {
          final Map<String, dynamic> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await performHeavyComputation($dsr.$2($req.args[0]));
          } finally {}
          return $res;
        },
        _$processLargeDataSetId: ($req) async {
          final Map<String, dynamic> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await processLargeDataSet(
                $dsr.$3($req.args[0]), $dsr.$0($req.args[1]));
          } finally {}
          return $res;
        },
        _$processSqlSuggestionItemsId: ($req) async {
          final List<Map<String, dynamic>> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await processSqlSuggestionItems(
                $dsr.$3($req.args[0]), $dsr.$0($req.args[1]));
          } finally {}
          return $res;
        },
        _$processSuggestionsId: ($req) async {
          final Set<String> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await processSuggestions($dsr.$0($req.args[0]),
                $dsr.$4($req.args[1]), $dsr.$5($req.args[2]));
          } finally {}
          return $res;
        },
        _$processTableChunkId: ($req) async {
          final Map<String, dynamic> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await processTableChunk(
                $dsr.$3($req.args[0]),
                $dsr.$0($req.args[1]),
                $dsr.$6($req.args[2]),
                $dsr.$0($req.args[3]));
          } finally {}
          return $res;
        },
        _$processWithProgressId: ($req) {
          final Stream<Map<String, dynamic>> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = processWithProgress($dsr.$2($req.args[0]));
          } finally {}
          return $res;
        },
        _$validateDataId: ($req) async {
          final Map<String, dynamic> $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await validateData(
                $dsr.$3($req.args[0]), $dsr.$7($req.args[1]));
          } finally {}
          return $res;
        },
      });
}

/// Invoker for SuggestionWorkerPool, implements the public interface to invoke the
/// remote service.
base mixin _$SuggestionWorkerPool$Invoker on sq.Invoker
    implements SuggestionWorkerPool {
  @override
  Future<dynamic> decodeJson(String jsonString) =>
      send(_$decodeJsonId, args: [jsonString]);

  @override
  Future<String> encodeJson(dynamic data) async {
    final dynamic $res = await send(_$encodeJsonId, args: [data]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$0($res);
    } finally {}
  }

  @override
  Future<Map<String, dynamic>> performHeavyComputation(
      Map<String, dynamic> params) async {
    final dynamic $res =
        await send(_$performHeavyComputationId, args: [params]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$2($res);
    } finally {}
  }

  @override
  Future<Map<String, dynamic>> processLargeDataSet(
      List<Map<String, dynamic>> data, String operation) async {
    final dynamic $res =
        await send(_$processLargeDataSetId, args: [data, operation]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$2($res);
    } finally {}
  }

  @override
  Future<List<Map<String, dynamic>>> processSqlSuggestionItems(
      List<Map<String, dynamic>> queryTables, String datasourceType) async {
    final dynamic $res = await send(_$processSqlSuggestionItemsId,
        args: [queryTables, datasourceType]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$3($res);
    } finally {}
  }

  @override
  Future<Set<String>> processSuggestions(String prefix,
      List<String> customWords, Map<String, List<String>> suggestions) async {
    final dynamic $res = await send(_$processSuggestionsId,
        args: [prefix, customWords, suggestions]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$8($res);
    } finally {}
  }

  @override
  Future<Map<String, dynamic>> processTableChunk(
      List<Map<String, dynamic>> chunkData,
      String datasourceType,
      int chunkIndex,
      String taskId) async {
    final dynamic $res = await send(_$processTableChunkId,
        args: [chunkData, datasourceType, chunkIndex, taskId]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$2($res);
    } finally {}
  }

  @override
  Stream<Map<String, dynamic>> processWithProgress(
      Map<String, dynamic> params) {
    final Stream $res = stream(_$processWithProgressId, args: [params]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $res.map($dsr.$2);
    } finally {}
  }

  @override
  Future<Map<String, dynamic>> validateData(
      List<Map<String, dynamic>> data, Map<String, String> schema) async {
    final dynamic $res = await send(_$validateDataId, args: [data, schema]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$2($res);
    } finally {}
  }
}

/// Facade for SuggestionWorkerPool, implements other details of the service unrelated to
/// invoking the remote service.
base mixin _$SuggestionWorkerPool$Facade implements SuggestionWorkerPool {}

/// WorkerService class for SuggestionWorkerPool
base class _$SuggestionWorkerPool$WorkerService extends SuggestionWorkerPool
    implements sq.WorkerService {
  _$SuggestionWorkerPool$WorkerService() : super();

  @override
  sq.OperationsMap get operations => _$getOperations();
}

/// Service initializer for SuggestionWorkerPool
sq.WorkerService $SuggestionWorkerPoolInitializer(sq.WorkerRequest $req) =>
    _$SuggestionWorkerPool$WorkerService();

/// Worker for SuggestionWorkerPool
base class SuggestionWorkerPoolWorker extends sq.Worker
    with _$SuggestionWorkerPool$Invoker, _$SuggestionWorkerPool$Facade
    implements SuggestionWorkerPool {
  SuggestionWorkerPoolWorker(
      {sq.PlatformThreadHook? threadHook,
      sq.ExceptionManager? exceptionManager})
      : super($SuggestionWorkerPoolActivator(sq.Squadron.platformType),
            threadHook: threadHook, exceptionManager: exceptionManager);

  SuggestionWorkerPoolWorker.vm(
      {sq.PlatformThreadHook? threadHook,
      sq.ExceptionManager? exceptionManager})
      : super($SuggestionWorkerPoolActivator(sq.SquadronPlatformType.vm),
            threadHook: threadHook, exceptionManager: exceptionManager);

  SuggestionWorkerPoolWorker.js(
      {sq.PlatformThreadHook? threadHook,
      sq.ExceptionManager? exceptionManager})
      : super($SuggestionWorkerPoolActivator(sq.SquadronPlatformType.js),
            threadHook: threadHook, exceptionManager: exceptionManager);

  @override
  List? getStartArgs() => null;
}

/// Worker pool for SuggestionWorkerPool
base class SuggestionWorkerPoolWorkerPool
    extends sq.WorkerPool<SuggestionWorkerPoolWorker>
    with _$SuggestionWorkerPool$Facade
    implements SuggestionWorkerPool {
  SuggestionWorkerPoolWorkerPool(
      {sq.PlatformThreadHook? threadHook,
      sq.ExceptionManager? exceptionManager,
      sq.ConcurrencySettings? concurrencySettings})
      : super(
            (sq.ExceptionManager exceptionManager) =>
                SuggestionWorkerPoolWorker(
                    threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  SuggestionWorkerPoolWorkerPool.vm(
      {sq.PlatformThreadHook? threadHook,
      sq.ExceptionManager? exceptionManager,
      sq.ConcurrencySettings? concurrencySettings})
      : super(
            (sq.ExceptionManager exceptionManager) =>
                SuggestionWorkerPoolWorker.vm(
                    threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  SuggestionWorkerPoolWorkerPool.js(
      {sq.PlatformThreadHook? threadHook,
      sq.ExceptionManager? exceptionManager,
      sq.ConcurrencySettings? concurrencySettings})
      : super(
            (sq.ExceptionManager exceptionManager) =>
                SuggestionWorkerPoolWorker.js(
                    threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  @override
  Future<dynamic> decodeJson(String jsonString) =>
      execute((w) => w.decodeJson(jsonString));

  @override
  Future<String> encodeJson(dynamic data) => execute((w) => w.encodeJson(data));

  @override
  Future<Map<String, dynamic>> performHeavyComputation(
          Map<String, dynamic> params) =>
      execute((w) => w.performHeavyComputation(params));

  @override
  Future<Map<String, dynamic>> processLargeDataSet(
          List<Map<String, dynamic>> data, String operation) =>
      execute((w) => w.processLargeDataSet(data, operation));

  @override
  Future<List<Map<String, dynamic>>> processSqlSuggestionItems(
          List<Map<String, dynamic>> queryTables, String datasourceType) =>
      execute((w) => w.processSqlSuggestionItems(queryTables, datasourceType));

  @override
  Future<Set<String>> processSuggestions(String prefix,
          List<String> customWords, Map<String, List<String>> suggestions) =>
      execute((w) => w.processSuggestions(prefix, customWords, suggestions));

  @override
  Future<Map<String, dynamic>> processTableChunk(
          List<Map<String, dynamic>> chunkData,
          String datasourceType,
          int chunkIndex,
          String taskId) =>
      execute((w) =>
          w.processTableChunk(chunkData, datasourceType, chunkIndex, taskId));

  @override
  Stream<Map<String, dynamic>> processWithProgress(
          Map<String, dynamic> params) =>
      stream((w) => w.processWithProgress(params));

  @override
  Future<Map<String, dynamic>> validateData(
          List<Map<String, dynamic>> data, Map<String, String> schema) =>
      execute((w) => w.validateData(data, schema));
}

final class _$Deser extends sq.MarshalingContext {
  _$Deser({super.contextAware});
  late final $0 = value<String>();
  late final $1 = value<Object>();
  late final $2 = nmap<String, Object>(kcast: $0, vcast: $1);
  late final $3 = list<Map<String, dynamic>>($2);
  late final $4 = list<String>($0);
  late final $5 = map<String, List<String>>(kcast: $0, vcast: $4);
  late final $6 = value<int>();
  late final $7 = map<String, String>(kcast: $0, vcast: $0);
  late final $8 = set<String>($0);
}
