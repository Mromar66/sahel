import 'system_session_id_stub.dart'
    if (dart.library.ffi) 'system_session_id_ffi.dart'
    as platform;

/// Identifies the current Windows logon session, which survives app restarts
/// and changes when Windows ends that session.
String? currentSystemSessionId() => platform.currentSystemSessionId();

/// Provides a second check that distinguishes Windows boots even if a logon
/// identifier happens to be reused after restart.
int? currentSystemBootTimeMs() => platform.currentSystemBootTimeMs();
