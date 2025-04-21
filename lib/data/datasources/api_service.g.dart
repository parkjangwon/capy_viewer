// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$apiServiceHash() => r'a4fedc69412ae7e5c1dc156fa8389fd543f5eb38';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ApiService extends BuildlessNotifier<ApiService> {
  late final bool forceRefresh;

  ApiService build({
    bool forceRefresh = false,
  });
}

/// See also [ApiService].
@ProviderFor(ApiService)
const apiServiceProvider = ApiServiceFamily();

/// See also [ApiService].
class ApiServiceFamily extends Family<ApiService> {
  /// See also [ApiService].
  const ApiServiceFamily();

  /// See also [ApiService].
  ApiServiceProvider call({
    bool forceRefresh = false,
  }) {
    return ApiServiceProvider(
      forceRefresh: forceRefresh,
    );
  }

  @override
  ApiServiceProvider getProviderOverride(
    covariant ApiServiceProvider provider,
  ) {
    return call(
      forceRefresh: provider.forceRefresh,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'apiServiceProvider';
}

/// See also [ApiService].
class ApiServiceProvider extends NotifierProviderImpl<ApiService, ApiService> {
  /// See also [ApiService].
  ApiServiceProvider({
    bool forceRefresh = false,
  }) : this._internal(
          () => ApiService()..forceRefresh = forceRefresh,
          from: apiServiceProvider,
          name: r'apiServiceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$apiServiceHash,
          dependencies: ApiServiceFamily._dependencies,
          allTransitiveDependencies:
              ApiServiceFamily._allTransitiveDependencies,
          forceRefresh: forceRefresh,
        );

  ApiServiceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.forceRefresh,
  }) : super.internal();

  final bool forceRefresh;

  @override
  ApiService runNotifierBuild(
    covariant ApiService notifier,
  ) {
    return notifier.build(
      forceRefresh: forceRefresh,
    );
  }

  @override
  Override overrideWith(ApiService Function() create) {
    return ProviderOverride(
      origin: this,
      override: ApiServiceProvider._internal(
        () => create()..forceRefresh = forceRefresh,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        forceRefresh: forceRefresh,
      ),
    );
  }

  @override
  NotifierProviderElement<ApiService, ApiService> createElement() {
    return _ApiServiceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ApiServiceProvider && other.forceRefresh == forceRefresh;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, forceRefresh.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ApiServiceRef on NotifierProviderRef<ApiService> {
  /// The parameter `forceRefresh` of this provider.
  bool get forceRefresh;
}

class _ApiServiceProviderElement
    extends NotifierProviderElement<ApiService, ApiService> with ApiServiceRef {
  _ApiServiceProviderElement(super.provider);

  @override
  bool get forceRefresh => (origin as ApiServiceProvider).forceRefresh;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
