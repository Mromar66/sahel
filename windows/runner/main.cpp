#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(0, 0);
  // The «صفو» reference window is a 1034x712 frame: an 8px DWM border on each
  // side, a 31px title strip and a 1018x673 client area. Creating a 1034x712
  // Win32 window therefore reproduces the reference client area exactly, so
  // every table column and field keeps its natural size (no stretching).
  Win32Window::Size size(1034, 712);
  if (!window.Create(L"\u0635\u0641\u0648 \u0644\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0623\u0639\u0645\u0627\u0644", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Centre the window on the desktop instead of covering the whole screen.
  RECT frame;
  if (::GetWindowRect(window.GetHandle(), &frame)) {
    const int frameWidth = frame.right - frame.left;
    const int frameHeight = frame.bottom - frame.top;
    const int screenWidth = ::GetSystemMetrics(SM_CXSCREEN);
    const int screenHeight = ::GetSystemMetrics(SM_CYSCREEN);
    const int x = (screenWidth - frameWidth) / 2;
    const int y = (screenHeight - frameHeight) / 2;
    ::SetWindowPos(window.GetHandle(), nullptr, x, y, 0, 0,
                   SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
