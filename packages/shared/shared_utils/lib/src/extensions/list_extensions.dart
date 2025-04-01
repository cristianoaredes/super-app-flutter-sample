import 'package:collection/collection.dart';


extension ListExtensions<T> on List<T> {
  
  T? get firstOrNull => isEmpty ? null : first;

  
  T? get lastOrNull => isEmpty ? null : last;

  
  T? get randomOrNull =>
      isEmpty ? null : this[DateTime.now().millisecondsSinceEpoch % length];

  
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) {
      return null;
    }
    return this[index];
  }

  
  bool containsAll(List<T> elements) {
    return elements.every((element) => contains(element));
  }

  
  bool containsAny(List<T> elements) {
    return elements.any((element) => contains(element));
  }

  
  bool equalsIgnoreOrder(List<T> other) {
    if (length != other.length) {
      return false;
    }

    final thisGrouped = groupBy(this, (e) => e);
    final otherGrouped = groupBy(other, (e) => e);

    if (thisGrouped.length != otherGrouped.length) {
      return false;
    }

    for (final entry in thisGrouped.entries) {
      final otherValue = otherGrouped[entry.key];
      if (otherValue == null || otherValue.length != entry.value.length) {
        return false;
      }
    }

    return true;
  }

  
  List<T> distinct() {
    return toSet().toList();
  }

  
  List<T> distinctBy<K>(K Function(T) keySelector) {
    final result = <T>[];
    final keys = <K>{};

    for (final element in this) {
      final key = keySelector(element);
      if (keys.add(key)) {
        result.add(element);
      }
    }

    return result;
  }

  
  Map<K, List<T>> groupByKey<K>(K Function(T) keySelector) {
    return groupBy(this, keySelector);
  }

  
  List<List<T>> chunked(int size) {
    if (size <= 0) {
      throw ArgumentError('O tamanho do chunk deve ser maior que zero');
    }

    final result = <List<T>>[];
    for (int i = 0; i < length; i += size) {
      result.add(sublist(i, i + size > length ? length : i + size));
    }

    return result;
  }

  
  ({List<T> matches, List<T> nonMatches}) partition(
      bool Function(T) predicate) {
    final matches = <T>[];
    final nonMatches = <T>[];

    for (final element in this) {
      if (predicate(element)) {
        matches.add(element);
      } else {
        nonMatches.add(element);
      }
    }

    return (matches: matches, nonMatches: nonMatches);
  }

  
  num sum() {
    if (isEmpty) return 0;
    if (T is num) {
      return (this as List<num>).fold<num>(0, (a, b) => a + b);
    }
    throw UnsupportedError(
        'A operação sum() só é suportada para listas numéricas');
  }

  
  double average() {
    if (isEmpty) return 0.0;
    if (T is num) {
      return (this as List<num>).fold<num>(0, (a, b) => a + b) / length;
    }
    throw UnsupportedError(
        'A operação average() só é suportada para listas numéricas');
  }

  
  T? min() {
    if (isEmpty) return null;
    if (T is Comparable) {
      return (this as List<Comparable>)
          .reduce((a, b) => a.compareTo(b) < 0 ? a : b) as T;
    }
    throw UnsupportedError(
        'A operação min() só é suportada para listas comparáveis');
  }

  
  T? max() {
    if (isEmpty) return null;
    if (T is Comparable) {
      return (this as List<Comparable>)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b) as T;
    }
    throw UnsupportedError(
        'A operação max() só é suportada para listas comparáveis');
  }
}
