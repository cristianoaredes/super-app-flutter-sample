
abstract class EventBusService {
  
  void publish<T>(String eventName, T data);

  
  Stream<T> subscribe<T>(String eventName);

  
  void unsubscribe(String eventName);

  
  bool hasSubscribers(String eventName);

  
  void clear();
}


class AppEvent<T> {
  final String name;
  final T data;
  final DateTime timestamp;
  final String? source;

  AppEvent({
    required this.name,
    required this.data,
    String? source,
  })  : timestamp = DateTime.now(),
        source = source;

  @override
  String toString() =>
      'AppEvent(name: $name, data: $data, timestamp: $timestamp, source: $source)';
}
