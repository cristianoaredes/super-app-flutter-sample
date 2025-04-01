import 'application_event.dart';


abstract class ApplicationHub {
  
  void subscribe<T extends ApplicationEvent>(
    String eventType,
    void Function(T event) callback,
  );
  
  
  void unsubscribe(String eventType, Function callback);
  
  
  void publish(ApplicationEvent event);
  
  
  T? getLastEvent<T extends ApplicationEvent>(String eventType);
  
  
  void clearSubscriptions();
}
