# Worker and Isolate Guidelines

## Overview

ZingData uses **Squadron** (advanced) and **worker_manager** (simple) for offloading CPU-intensive tasks to isolates. This prevents UI jank but requires careful handling of data serialization.

## Critical Rules

### 1. Only Pass Serializable Data

**Can Pass:**
- Primitives: `int`, `double`, `bool`, `String`, `null`
- Collections of primitives: `List<int>`, `Map<String, String>`, etc.
- Simple serializable objects (that can be converted to JSON)

**NEVER Pass:**
- Service instances (`NetworkService`, `AuthService`, etc.)
- Futures, Streams, or other async primitives
- Closures that capture non-serializable objects
- Complex objects with service dependencies
- Any object with async callbacks

### 2. Size-Based Decision Making

Only use isolates when the performance benefit outweighs the overhead:

```dart
if (data.length < 500) {
  // Process on main thread for small datasets
  result = processData(data);
} else {
  // Use isolate for larger datasets
  result = await workerManager.execute<ResultType>(
    () => processData(serializedData)
  );
}
```

**Rule of thumb**: Use isolates for datasets with 500+ items or computations taking >100ms.

### 3. Always Implement Fallbacks

Never assume isolate execution will succeed:

```dart
try {
  result = await workerManager.execute<ResultType>(
    () => heavyComputation(data)
  );
} catch (e) {
  // Fallback to main thread
  logger.warning('Isolate failed, falling back to main thread: $e');
  result = heavyComputation(data);
}
```

### 4. Serialize Complex Objects

Example pattern for complex objects:

```dart
// BEFORE: Complex objects
final List<LatLng> latLngList = [...];

// Serialize to primitives
final serializedList = latLngList.map((latlng) => [
  latlng.latitude,
  latlng.longitude,
]).toList();

// Execute in isolate
final result = await workerManager.execute<LatLngBounds?>(
  () {
    // Reconstruct inside isolate
    final reconverted = (serializedList as List).map((point) =>
      LatLng(point[0] as double, point[1] as double)
    ).toList();
    
    return MapService.boundsFromLatLngList({'list': reconverted});
  }
);
```

## Common Error

```
Illegal argument in isolate message: object is unsendable
Library:'dart:async' Class: _Future
```

**Cause**: Trying to send non-serializable objects to isolate.

**Fix**: Serialize the data first, or process on main thread.

## Squadron vs Worker Manager

### Squadron (Advanced)
- More complex setup
- Better for long-running workers
- Type-safe worker definitions
- Used in: `lib/workers/`, `lib/services/data_worker_service.dart`
- Requires code generation

### Worker Manager (Simple)
- Simple one-off tasks
- Easy to use: `workerManager.execute(() => task())`
- Good for ad-hoc heavy computations
- No code generation needed

## Services Using Workers

### DataWorkerService
Location: `lib/services/data_worker_service.dart`

Uses Squadron for:
- Data processing
- Query result transformations
- Complex calculations

Generated files:
- `data_worker_service.worker.g.dart` (worker implementation)
- `data_worker_service.activator.g.dart` (activator)
- `data_worker_service.web.g.dart` (web-specific)
- `data_worker_service.vm.g.dart` (VM-specific)

### WorkerManagerService
Location: `lib/services/worker_manager_service.dart`

Manages worker pool and execution.

## Best Practices

### ✅ Good Patterns

```dart
// 1. Size-based decision
if (rows.length > 500) {
  result = await workerManager.execute(() => process(rows));
} else {
  result = process(rows);
}

// 2. Serialization
final jsonData = model.toJson();
result = await workerManager.execute(() => processJson(jsonData));

// 3. Fallback
try {
  result = await isolateCompute();
} catch (e) {
  result = mainThreadCompute();
}
```

### ❌ Bad Patterns

```dart
// 1. Passing service
workerManager.execute(() => networkService.fetch()); // ❌ NEVER

// 2. Passing Future
workerManager.execute(() => futureResult); // ❌ NEVER

// 3. Capturing complex context
workerManager.execute(() => _processWithService(data)); // ❌ May fail

// 4. No fallback
result = await workerManager.execute(() => process(data)); // ❌ Risky
```

## Performance Considerations

### When to Use Isolates
- Processing large datasets (>500 items)
- Complex calculations (>100ms)
- Data transformations
- JSON parsing/serialization for large objects
- Map calculations (bounds, clustering)

### When NOT to Use Isolates
- Simple operations (<100ms)
- Small datasets (<500 items)
- When serialization overhead exceeds computation cost
- Frequent, rapid operations (overhead becomes significant)

## Testing Workers

1. **Test with various data sizes**: Small, medium, large datasets
2. **Test failure scenarios**: Verify fallback works
3. **Test serialization**: Ensure data round-trips correctly
4. **Monitor performance**: Compare isolate vs main thread times

## Debugging

### Web Workers
See: `docs/SQUADRON_WEB_DEBUGGING.md`

Web workers have special considerations:
- Different isolate implementation
- Separate JavaScript context
- Debugging challenges

### Common Issues
1. **Unsendable objects**: Serialize before sending
2. **Slow performance**: Check dataset size threshold
3. **Worker crashes**: Add try-catch and fallback
4. **Memory issues**: Process in batches

## Related Documentation

- `docs/worker_manager_guide.md` - Comprehensive guide
- `docs/SQUADRON_WEB_DEBUGGING.md` - Web-specific debugging
- `lib/services/data_worker_service.dart` - Main worker service
