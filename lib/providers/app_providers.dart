import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/club_service.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/chat_service.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/image_upload_service.dart';
import 'package:bunny/services/saved_service.dart';
import 'package:bunny/services/verification_service.dart';
import 'package:bunny/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

List<SingleChildWidget> buildAppProviders() {
  return <SingleChildWidget>[
    ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
    Provider<ClubService>(create: (_) => ClubService()),
    Provider<UserService>(create: (_) => UserService()),
    Provider<ImageUploadService>(create: (_) => ImageUploadService()),
    Provider<SavedService>(create: (_) => SavedService()),
    Provider<VerificationService>(create: (_) => VerificationService()),
    ChangeNotifierProvider<ChatService>(create: (_) => ChatService()),
    ChangeNotifierProvider<NotificationService>(create: (_) => NotificationService()),
    ProxyProvider2<NotificationService, UserService, PartyService>(
      create: (context) => PartyService(
        notificationService: context.read<NotificationService>(),
        userService: context.read<UserService>(),
      ),
      update: (context, notificationService, userService, previous) => PartyService(
        notificationService: notificationService,
        userService: userService,
      ),
    ),
  ];
}
