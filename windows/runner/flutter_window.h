#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "native_splash_overlay.h"
#include "win32_window.h"

class FlutterWindow : public Win32Window
{
public:
  explicit FlutterWindow(const flutter::DartProject &project);
  virtual ~FlutterWindow();

protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

private:
  void TryDismissSplash();
  void ForceDismissSplash();

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<NativeSplashOverlay> splash_overlay_;

  bool is_animation_finished_ = false;
  bool is_flutter_first_frame_ready_ = false;
  bool is_splash_dismissed_ = false;

  static constexpr UINT_PTR kSafetyTimerId = 2001;
};

#endif // RUNNER_FLUTTER_WINDOW_H_