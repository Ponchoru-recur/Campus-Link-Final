import 'package:flutter/material.dart';
import 'user_service.dart';

/// Makes [UserService] available down the widget tree via [InheritedNotifier].
///
/// Usage: `UserService.of(context).isRevoked`
class UserProvider extends InheritedNotifier<UserService> {
  const UserProvider({
    super.key,
    required UserService service,
    required super.child,
  }) : super(notifier: service);

  static UserService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<UserProvider>();
    assert(provider != null, 'No UserProvider found in context');
    return provider!.notifier!;
  }
}