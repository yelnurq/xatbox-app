#ifndef RUNNER_PREVIEW_WINDOW_H_
#define RUNNER_PREVIEW_WINDOW_H_

#include <windows.h>

#include <string>

// Quick Look for Windows: a window that hosts the preview handler Explorer's
// preview pane uses for the file type (PDF, Office documents, pictures,
// text). False when no preview handler is registered for the type.
bool ShowPreviewWindow(HWND owner, const std::wstring& path);

#endif  // RUNNER_PREVIEW_WINDOW_H_
