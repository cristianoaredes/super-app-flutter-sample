import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/foundation.dart';


class ApplicationHubImpl implements ApplicationHub {
  final Map<String, List<Function>> _subscribers = {};
  final Map<String, ApplicationEvent> _lastEvents = {};
  
  @override
  void subscribe<T extends ApplicationEvent>(
    String eventType,
    void Function(T event) callback,
  ) {
    if (!_subscribers.containsKey(eventType)) {
      _subscribers[eventType] = [];
    }
    
    _subscribers[eventType]!.add(callback);
    
    
    final lastEvent = _lastEvents[eventType];
    if (lastEvent != null && lastEvent is T) {
      callback(lastEvent);
    }
  }
  
  @override
  void unsubscribe(String eventType, Function callback) {
    if (_subscribers.containsKey(eventType)) {
      _subscribers[eventType]!.remove(callback);
      
      if (_subscribers[eventType]!.isEmpty) {
        _subscribers.remove(eventType);
      }
    }
  }
  
  @override
  void publish(ApplicationEvent event) {
    final eventType = event.eventType;
    
    
    _lastEvents[eventType] = event;
    
    
    if (_subscribers.containsKey(eventType)) {
      for (final callback in _subscribers[eventType]!) {
        try {
          callback(event);
        } catch (e) {
          debugPrint('Error notifying subscriber: $e');
        }
      }
    }
  }
  
  @override
  T? getLastEvent<T extends ApplicationEvent>(String eventType) {
    final lastEvent = _lastEvents[eventType];
    if (lastEvent != null && lastEvent is T) {
      return lastEvent;
    }
    return null;
  }
  
  @override
  void clearSubscriptions() {
    _subscribers.clear();
  }
}
