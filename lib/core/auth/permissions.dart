/// Permission codes referenced by `x-required-permission` in the API spec.
/// The UI hides/disables features ahead of the server's 403 (see `GET /me`).
abstract final class Permissions {
  static const mailRead = 'mail.read';
  static const mailSend = 'mail.send';

  /// Old built-in webmail chat (`/chat/*`); not the future Chat Service.
  static const messagesSend = 'messages.send';
  static const officialRead = 'official.read';
  static const officialSendDepartment = 'official.send.department';
  static const officialSendOrganization = 'official.send.organization';

  // Calendar (`/calendar/*`).
  static const calendarRead = 'calendar.events.read';
  static const calendarCreate = 'calendar.events.create';
  static const calendarManageOwn = 'calendar.events.manage_own';
  static const calendarManageOrg = 'organization.calendar.manage';
}
