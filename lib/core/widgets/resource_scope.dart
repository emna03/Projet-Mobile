import 'package:flutter/material.dart';
import '../../features/resources/repositories/resource_repository.dart';
import '../../features/resources/viewmodels/resource_viewmodel.dart';

final ResourceViewModel resourceViewModel = ResourceViewModel(ResourceRepository());

class ResourceScope extends InheritedNotifier<ResourceViewModel> {
  const ResourceScope({
    super.key,
    required ResourceViewModel notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ResourceViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ResourceScope>();
    assert(scope != null, 'ResourceScope introuvable');
    return scope!.notifier!;
  }
}
