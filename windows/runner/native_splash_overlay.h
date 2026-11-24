#ifndef RUNNER_NATIVE_SPLASH_OVERLAY_H_
#define RUNNER_NATIVE_SPLASH_OVERLAY_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <d2d1.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <functional>
#include <string>
#include <vector>

#include "svg_path_parser.h"

class NativeSplashOverlay
{
public:
    static constexpr UINT kMsgSplashDestroyed = WM_APP + 101;
    NativeSplashOverlay();
    ~NativeSplashOverlay();

    // ينشئ نافذة Overlay مسرّعة بالهاردوير فوق نافذة التطبيق الرئيسية من اللحظة 0ms
    bool Create(HWND parent_hwnd, std::function<void()> on_animation_complete);

    // يحدّث موقع وحجم الطبقة عند تحريك أو تكبير نافذة الويندوز
    void SyncToParentBounds();

    // يبدأ التلاشي الناعم (Fade Out) ثم يحرر كافة موارد GPU والنافذة
    void FadeOutAndDestroy(std::function<void()> on_destroyed);

private:
    struct AvatarSpec
    {
        std::wstring asset_name;
        float left_percent;
        float target_scale;
        float delay_ms;
        float shadow_offset;
        Microsoft::WRL::ComPtr<ID2D1Bitmap> bitmap;
    };

    static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
    LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

    void InitializeDeviceResources();
    void DiscardDeviceResources();
    Microsoft::WRL::ComPtr<ID2D1Bitmap> LoadBitmapFromFile(const std::wstring &path);
    std::wstring ResolveAssetPath(const std::wstring &relative_asset_path) const;

    void OnTimerTick();
    void Render();
    void DrawAvatar(const AvatarSpec &spec, float container_left, float container_top,
                    float container_w, float container_h, float avatar_base_size, float elapsed_ms);
    void DrawSvgStroke(float center_x, float top_y, float progress);

    static float EaseInOutCubic(float t);
    static float EaseOutCubic(float t);
    static float ComputeDropOffset(float norm_t, float drop_height);

    HWND parent_hwnd_ = nullptr;
    HWND overlay_hwnd_ = nullptr;

    Microsoft::WRL::ComPtr<ID2D1Factory> d2d_factory_;
    Microsoft::WRL::ComPtr<IWICImagingFactory> wic_factory_;
    Microsoft::WRL::ComPtr<ID2D1HwndRenderTarget> render_target_;
    Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> white_brush_;
    Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> placeholder_brush_;
    Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> stroke_brush_;

    std::vector<AvatarSpec> avatars_;
    std::vector<SvgContour> svg_contours_;
    float total_svg_length_ = 0.0f;

    LARGE_INTEGER perf_freq_{};
    LARGE_INTEGER start_time_{};
    LARGE_INTEGER fade_start_time_{};

    bool animation_completed_notified_ = false;
    bool has_started_clock_ = false;
    bool is_fading_out_ = false;
    bool is_destroyed_ = false;

    std::function<void()> on_animation_complete_;
    std::function<void()> on_destroyed_;

    static constexpr UINT_PTR kAnimTimerId = 1001;
    static constexpr float kLogoBoxWidth = 760.0f;
    static constexpr float kLogoBoxHeight = 85.0f;
    static constexpr float kStrokeWidth = 1.8f;
};

#endif // RUNNER_NATIVE_SPLASH_OVERLAY_H_