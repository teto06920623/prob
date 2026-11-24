#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view())
  {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  this->Show();

  splash_overlay_ = std::make_unique<NativeSplashOverlay>();
  splash_overlay_->Create(GetHandle(), [this]()
                          {
    is_animation_finished_ = true;
    TryDismissSplash(); });

  // مؤقت أمان أقصى (8 ثوانٍ) لضمان فتح التطبيق تحت أي ظرف
  SetTimer(GetHandle(), kSafetyTimerId, 8000, nullptr);

  flutter_controller_->engine()->SetNextFrameCallback([this]()
                                                      {
    is_flutter_first_frame_ready_ = true;
    TryDismissSplash(); });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy()
{
  KillTimer(GetHandle(), kSafetyTimerId);
  splash_overlay_.reset();

  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept
{
  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result)
    {
      return *result;
    }
  }

  switch (message)
  {
  case WM_FONTCHANGE:
    flutter_controller_->engine()->ReloadSystemFonts();
    break;

  case WM_MOVE:
  case WM_SIZE:
    if (splash_overlay_)
    {
      splash_overlay_->SyncToParentBounds();
    }
    break;

  case WM_TIMER:
    if (wparam == kSafetyTimerId)
    {
      ForceDismissSplash();
      return 0;
    }
    break;

  case NativeSplashOverlay::kMsgSplashDestroyed:
    splash_overlay_.reset();
    return 0;

  default:
    break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::TryDismissSplash()
{
  if (is_animation_finished_ && is_flutter_first_frame_ready_)
  {
    ForceDismissSplash();
  }
}

void FlutterWindow::ForceDismissSplash()
{
  if (is_splash_dismissed_)
    return;
  is_splash_dismissed_ = true;
  KillTimer(GetHandle(), kSafetyTimerId);

  if (splash_overlay_)
  {
    splash_overlay_->FadeOutAndDestroy(nullptr);
  }
}