# Worker Manager Usage Guide

## Overview

`worker_manager` provides an easy way to offload CPU-intensive tasks to background isolates, preventing UI jank. However, data passed to isolates must be serializable. This document provides guidelines for properly using `worker_manager` in our application.

## Common Pitfalls

When using `workerManager.execute()`, you might encounter this error:

```
Illegal argument in isolate message: object is unsendable - Library:'dart:async' Class: _Future
```

This occurs when you try to send non-serializable objects to an isolate, such as:
- Service instances (NetworkService, StorageService, etc.)
- Futures, Streams, or other async primitives
- Closures that capture references to non-serializable objects
- Complex objects with closures or service dependencies

## Best Practices

### 1. Only Send Serializable Data

Only pass primitive types and simple collections to an isolate:
- Primitives: `int`, `double`, `bool`, `String`
- Collections of primitives: `List<int>`, `Map<String, String>`, etc.
- Simple data classes with primitive fields

```dart
// GOOD
workerManager.execute<int>(() => calculateSum([1, 2, 3, 4, 5]));

// BAD - Captures references to complex objects
workerManager.execute<int>(() => _networkService.processData(data));
```

### 2. Serialize Complex Objects

If you need to pass complex objects, first serialize them to a simpler format:

```dart
// Instead of passing LatLng objects directly
final serializedList = latLngList.map((latlng) => [
  latlng.latitude, 
  latlng.longitude,
]).toList();

// Then reconstruct inside the isolate
workerManager.execute<LatLngBounds?>(() {
  final reconvertedList = (serializedList as List).map((point) => 
    LatLng(point[0] as double, point[1] as double)
  ).toList();
  
  return MapService.boundsFromLatLngList({'list': reconvertedList});
});
```

### 3. Size-Based Decision Making

Only use isolates when the performance benefit outweighs the overhead:

```dart
if (data.length < 500) {
  // For small datasets, process on main thread
  result = processData(data);
} else {
  // For larger datasets, use isolate
  result = await workerManager.execute<ResultType>(() => processData(serializedData));
}
```

### 4. Fallback Mechanism

Always implement a fallback for when isolate execution fails:

```dart
try {
  result = await workerManager.execute<ResultType>(() => heavyComputation(data));
} catch (e) {
  errorLog('Worker error: $e');
  // Fallback to main thread
  result = heavyComputation(data);
}
```

### 5. Static Methods for Computation

Prefer using static utility methods that don't capture external context:

```dart
// GOOD
class Calculator {
  static int computeSum(List<int> numbers) {
    return numbers.reduce((a, b) => a + b);
  }
}

workerManager.execute<int>(() => Calculator.computeSum([1, 2, 3, 4, 5]));

// BAD
class Calculator {
  final Config _config; // Non-serializable
  
  int computeSum(List<int> numbers) {
    // Uses _config internally
    return numbers.reduce((a, b) => a + b * _config.multiplier);
  }
}

// This will fail because it captures "this"
workerManager.execute<int>(() => calculator.computeSum([1, 2, 3, 4, 5]));
```

### 6. Use Utility Functions

Create specialized utility functions that encapsulate all the complexity of using isolates safely:

```dart
// Example: The calculateLatLngBoundsSafely utility function
// Usage is simple and consistent:
final bounds = await MapService.calculateLatLngBoundsSafely(
  latLngList,
  logError: (e) => errorLog(e),
);

// Behind the scenes it handles:
// 1. Size-based decision making
// 2. Safe serialization of complex objects
// 3. Error handling and fallbacks
// 4. Proper isolate execution
```

This approach encapsulates all the best practices in one place, making it safer and easier to use isolates throughout the app.

## Real-World Examples

### JSON Decoding

```dart
// For small responses, decode on main thread
if (response.body.length < 50 * 1024) { // 50KB
  return jsonDecode(response.body);
} else {
  // For large responses, use worker
  return await workerManager.execute<dynamic>(
    () => jsonDecode(jsonString)
  );
}
```

### Data Processing

```dart
// Extract just the data needed for computation
final dataPoints = complexObjects.map((obj) => obj.value).toList();

// Process in isolate
final result = await workerManager.execute<double>(
  () => computeAverage(dataPoints)
);
```

## Testing Isolate Compatibility

When in doubt whether your data is isolate-compatible, you can test with:

```dart
bool isIsolateCompatible(dynamic data) {
  try {
    // Try to encode to JSON and back as a simple test
    final encoded = jsonEncode(data);
    jsonDecode(encoded);
    return true;
  } catch (e) {
    print('Not isolate compatible: $e');
    return false;
  }
}
```

## Summary

- Only send serializable data to isolates
- Serialize complex objects before sending
- Use isolates only for computationally intensive tasks
- Always implement fallbacks
- Prefer static utility methods for isolate work
- Create specialized utility functions that encapsulate all best practices 