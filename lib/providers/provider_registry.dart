import '../core/errors/app_exception.dart';
import 'provider.dart';

/// Holds factories for bundled providers. The core app resolves providers by id
/// through this registry and never hard-codes a concrete provider.
class ProviderRegistry {
  ProviderRegistry();

  final Map<String, StreamProvider Function()> _factories = {};
  final Map<String, StreamProvider> _instances = {};

  void register(String id, StreamProvider Function() factory) {
    _factories[id] = factory;
  }

  bool contains(String id) => _factories.containsKey(id);

  Set<String> get ids => _factories.keys.toSet();

  StreamProvider create(String id) {
    if (!_factories.containsKey(id)) {
      throw AppException(
        AppErrorKind.pluginNotFound,
        message: 'Provider not found.',
        technical: id,
      );
    }
    return _instances.putIfAbsent(id, () => _factories[id]!());
  }

  List<StreamProvider> instantiateAll() => _factories.keys.map(create).toList();
}
