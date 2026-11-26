import 'dart:ffi';
import 'dart:io';

typedef _GetCurrentProcessNative = Pointer<Void> Function();
typedef _GetCurrentProcessDart = Pointer<Void> Function();
typedef _GetTickCount64Native = Uint64 Function();
typedef _GetTickCount64Dart = int Function();
typedef _OpenProcessTokenNative = Int32 Function(
  Pointer<Void>,
  Uint32,
  Pointer<Pointer<Void>>,
);
typedef _OpenProcessTokenDart = int Function(
  Pointer<Void>,
  int,
  Pointer<Pointer<Void>>,
);
typedef _GetTokenInformationNative = Int32 Function(
  Pointer<Void>,
  Uint32,
  Pointer<Void>,
  Uint32,
  Pointer<Uint32>,
);
typedef _GetTokenInformationDart = int Function(
  Pointer<Void>,
  int,
  Pointer<Void>,
  int,
  Pointer<Uint32>,
);
typedef _CloseHandleNative = Int32 Function(Pointer<Void>);
typedef _CloseHandleDart = int Function(Pointer<Void>);
typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _MallocDart = Pointer<Void> Function(int);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);

String? currentSystemSessionId() {
  if (!Platform.isWindows) return null;

  Pointer<Void> token = Pointer<Void>.fromAddress(0);
  Pointer<Void> tokenOutput = Pointer<Void>.fromAddress(0);
  Pointer<Void> statistics = Pointer<Void>.fromAddress(0);
  Pointer<Void> returnedLength = Pointer<Void>.fromAddress(0);
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final advapi32 = DynamicLibrary.open('advapi32.dll');
    final cRuntime = DynamicLibrary.open('msvcrt.dll');
    final allocate = cRuntime.lookupFunction<_MallocNative, _MallocDart>(
      'malloc',
    );
    final getCurrentProcess = kernel32
        .lookupFunction<_GetCurrentProcessNative, _GetCurrentProcessDart>(
          'GetCurrentProcess',
        );
    final openProcessToken = advapi32
        .lookupFunction<_OpenProcessTokenNative, _OpenProcessTokenDart>(
          'OpenProcessToken',
        );
    final getTokenInformation = advapi32
        .lookupFunction<_GetTokenInformationNative, _GetTokenInformationDart>(
          'GetTokenInformation',
        );

    tokenOutput = allocate(sizeOf<IntPtr>());
    statistics = allocate(64);
    returnedLength = allocate(sizeOf<Uint32>());
    if (tokenOutput.address == 0 ||
        statistics.address == 0 ||
        returnedLength.address == 0) {
      return null;
    }
    final tokenOutputPointer = tokenOutput.cast<Pointer<Void>>();
    tokenOutputPointer.value = Pointer<Void>.fromAddress(0);
    if (openProcessToken(getCurrentProcess(), 0x0008, tokenOutputPointer) ==
        0) {
      return null;
    }
    token = tokenOutputPointer.value;

    // TokenStatistics is value 10; AuthenticationId is the second LUID in
    // TOKEN_STATISTICS, stored as two consecutive 32-bit values.
    if (getTokenInformation(
          token,
          10,
          statistics,
          64,
          returnedLength.cast<Uint32>(),
        ) ==
        0) {
      return null;
    }
    final luid = statistics.cast<Uint32>();
    final lowPart = luid.elementAt(2).value;
    final highPart = luid.elementAt(3).value;
    return '${highPart.toRadixString(16).padLeft(8, '0')}:${lowPart.toRadixString(16).padLeft(8, '0')}';
  } on Object {
    return null;
  } finally {
    if (token.address != 0) {
      try {
        DynamicLibrary.open('kernel32.dll')
            .lookupFunction<_CloseHandleNative, _CloseHandleDart>(
              'CloseHandle',
            )(token);
      } on Object {
        // Ignore cleanup failures; session restoration will fail closed.
      }
    }
    try {
      final free = DynamicLibrary.open('msvcrt.dll')
          .lookupFunction<_FreeNative, _FreeDart>('free');
      for (final allocation in [tokenOutput, statistics, returnedLength]) {
        if (allocation.address != 0) free(allocation);
      }
    } on Object {
      // The OS releases these tiny temporary allocations when the process ends.
    }
  }
}

int? currentSystemBootTimeMs() {
  if (!Platform.isWindows) return null;
  try {
    final getTickCount64 = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<_GetTickCount64Native, _GetTickCount64Dart>(
          'GetTickCount64',
        );
    return DateTime.now().toUtc().millisecondsSinceEpoch - getTickCount64();
  } on Object {
    return null;
  }
}
