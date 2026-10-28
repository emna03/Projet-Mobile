import 'package:flutter/material.dart';
import '../../features/groups/models/group.dart';
import '../../features/groups/viewmodels/group_viewmodel.dart';
import '../../features/groups/views/create_group_page.dart';
import '../../features/groups/views/edit_group_page.dart';
import '../../features/groups/views/group_details_page.dart';
import '../../features/groups/views/groups_list_page.dart';

/// Routes constants and generator for the application.
class AppRoutes {
  static const String groupsList = '/groups';
  static const String groupDetails = '/group-details';
  static const String createGroup = '/create-group';
  static const String editGroup = '/edit-group';

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
    GroupViewModel viewModel,
  ) {
    switch (settings.name) {
      case groupsList:
        return MaterialPageRoute(
          builder: (_) => GroupsListPage(viewModel: viewModel),
        );
      case groupDetails:
        final group = settings.arguments as Group;
        return MaterialPageRoute(
          builder: (_) => GroupDetailsPage(group: group, viewModel: viewModel),
        );
      case createGroup:
        return MaterialPageRoute(
          builder: (_) => CreateGroupPage(viewModel: viewModel),
        );
      case editGroup:
        final group = settings.arguments as Group;
        return MaterialPageRoute(
          builder: (_) => EditGroupPage(group: group, viewModel: viewModel),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => GroupsListPage(viewModel: viewModel),
        );
    }
  }
}
