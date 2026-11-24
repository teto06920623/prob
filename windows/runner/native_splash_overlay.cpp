#include "native_splash_overlay.h"

#include <algorithm>
#include <cmath>

#pragma comment(lib, "d2d1.lib")
#pragma comment(lib, "windowscodecs.lib")

using Microsoft::WRL::ComPtr;

namespace
{
    constexpr wchar_t kOverlayWindowClass[] = L"TETO_NATIVE_SPLASH_OVERLAY";
    bool g_overlay_class_registered = false;
} // namespace

NativeSplashOverlay::NativeSplashOverlay()
{
    QueryPerformanceFrequency(&perf_freq_);
}

NativeSplashOverlay::~NativeSplashOverlay()
{
    if (overlay_hwnd_)
    {
        KillTimer(overlay_hwnd_, kAnimTimerId);
        DestroyWindow(overlay_hwnd_);
        overlay_hwnd_ = nullptr;
    }
    DiscardDeviceResources();
}

bool NativeSplashOverlay::Create(HWND parent_hwnd, std::function<void()> on_animation_complete)
{
    parent_hwnd_ = parent_hwnd;
    on_animation_complete_ = std::move(on_animation_complete);

    HINSTANCE hinstance = GetModuleHandle(nullptr);
    if (!g_overlay_class_registered)
    {
        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = NativeSplashOverlay::WndProc;
        wc.hInstance = hinstance;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = CreateSolidBrush(RGB(17, 17, 17));
        wc.lpszClassName = kOverlayWindowClass;
        if (!RegisterClassExW(&wc))
        {
            return false;
        }
        g_overlay_class_registered = true;
    }

    D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, d2d_factory_.GetAddressOf());
    CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                     IID_PPV_ARGS(wic_factory_.GetAddressOf()));

    // ترتيب الطبقات للتحكم في العمق (Z-Order): الخلفية (1, 5) ثم الوسطى (2, 4) وأخيراً الأمامية (3)
    avatars_ = {
        {L"assets\\avatars\\avatar_1.png", 0.15f, 0.85f, 150.0f, 5.0f, nullptr},
        {L"assets\\avatars\\avatar_5.png", 0.85f, 0.85f, 150.0f, 5.0f, nullptr},
        {L"assets\\avatars\\avatar_2.png", 0.32f, 0.95f, 350.0f, 9.0f, nullptr},
        {L"assets\\avatars\\avatar_4.png", 0.68f, 0.95f, 350.0f, 9.0f, nullptr},
        {L"assets\\avatars\\avatar_3.png", 0.50f, 1.15f, 550.0f, 14.0f, nullptr},
    };

    std::wstring svg_path = ResolveAssetPath(L"assets\\svg\\logo.svg");
    svg_contours_ = SvgPathParser::LoadFromSvgFile(
        svg_path, kLogoBoxWidth, kLogoBoxHeight, kStrokeWidth);

    total_svg_length_ = 0.0f;
    for (const auto &c : svg_contours_)
    {
        total_svg_length_ += c.total_length;
    }

    RECT client_rect{};
    GetClientRect(parent_hwnd_, &client_rect);
    POINT top_left{client_rect.left, client_rect.top};
    ClientToScreen(parent_hwnd_, &top_left);
    int width = (std::max)(1, static_cast<int>(client_rect.right - client_rect.left));
    int height = (std::max)(1, static_cast<int>(client_rect.bottom - client_rect.top));

    overlay_hwnd_ = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TOOLWINDOW,
        kOverlayWindowClass,
        L"",
        WS_POPUP,
        top_left.x,
        top_left.y,
        width,
        height,
        parent_hwnd_,
        nullptr,
        hinstance,
        this);

    if (!overlay_hwnd_)
    {
        return false;
    }

    SetLayeredWindowAttributes(overlay_hwnd_, 0, 255, LWA_ALPHA);
    ShowWindow(overlay_hwnd_, SW_SHOWNOACTIVATE);

    // نبدأ المؤقت وننتظر أول نبضة فعلية بعد فك تجميد إقلاع محرك Dart
    SetTimer(overlay_hwnd_, kAnimTimerId, 12, nullptr);
    return true;
}

void NativeSplashOverlay::SyncToParentBounds()
{
    if (!overlay_hwnd_ || !parent_hwnd_ || is_destroyed_)
        return;

    RECT client_rect{};
    GetClientRect(parent_hwnd_, &client_rect);
    POINT top_left{client_rect.left, client_rect.top};
    ClientToScreen(parent_hwnd_, &top_left);

    int width = (std::max)(1, static_cast<int>(client_rect.right - client_rect.left));
    int height = (std::max)(1, static_cast<int>(client_rect.bottom - client_rect.top));

    SetWindowPos(overlay_hwnd_, nullptr, top_left.x, top_left.y, width, height,
                 SWP_NOZORDER | SWP_NOACTIVATE);

    if (render_target_)
    {
        render_target_->Resize(D2D1::SizeU(static_cast<UINT32>(width), static_cast<UINT32>(height)));
    }
}

void NativeSplashOverlay::FadeOutAndDestroy(std::function<void()> on_destroyed)
{
    if (is_destroyed_ || is_fading_out_)
        return;
    is_fading_out_ = true;
    on_destroyed_ = std::move(on_destroyed);
    QueryPerformanceCounter(&fade_start_time_);
}

LRESULT CALLBACK NativeSplashOverlay::WndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
{
    NativeSplashOverlay *self = nullptr;
    if (message == WM_NCCREATE)
    {
        auto *cs = reinterpret_cast<CREATESTRUCTW *>(lparam);
        self = reinterpret_cast<NativeSplashOverlay *>(cs->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        self->overlay_hwnd_ = hwnd;
    }
    else
    {
        self = reinterpret_cast<NativeSplashOverlay *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    }

    if (self)
    {
        return self->HandleMessage(message, wparam, lparam);
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT NativeSplashOverlay::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam)
{
    switch (message)
    {
    case WM_TIMER:
        if (wparam == kAnimTimerId)
        {
            OnTimerTick();
            return 0;
        }
        break;

    case WM_PAINT:
    {
        PAINTSTRUCT ps{};
        BeginPaint(overlay_hwnd_, &ps);
        Render();
        EndPaint(overlay_hwnd_, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;

    default:
        break;
    }
    return DefWindowProcW(overlay_hwnd_, message, wparam, lparam);
}

void NativeSplashOverlay::InitializeDeviceResources()
{
    if (render_target_ || !d2d_factory_ || !overlay_hwnd_)
        return;

    RECT rc{};
    GetClientRect(overlay_hwnd_, &rc);
    D2D1_SIZE_U size = D2D1::SizeU(
        static_cast<UINT32>((std::max)(1L, rc.right - rc.left)),
        static_cast<UINT32>((std::max)(1L, rc.bottom - rc.top)));

    D2D1_RENDER_TARGET_PROPERTIES rt_props = D2D1::RenderTargetProperties();
    rt_props.dpiX = 96.0f;
    rt_props.dpiY = 96.0f;

    HRESULT hr = d2d_factory_->CreateHwndRenderTarget(
        rt_props,
        D2D1::HwndRenderTargetProperties(overlay_hwnd_, size, D2D1_PRESENT_OPTIONS_IMMEDIATELY),
        render_target_.GetAddressOf());

    if (SUCCEEDED(hr))
    {
        render_target_->SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
        render_target_->CreateSolidColorBrush(D2D1::ColorF(D2D1::ColorF::White), &white_brush_);
        render_target_->CreateSolidColorBrush(D2D1::ColorF(0xE0E0E0), &placeholder_brush_);
        render_target_->CreateSolidColorBrush(D2D1::ColorF(0x00FF88), &stroke_brush_);

        for (auto &spec : avatars_)
        {
            if (!spec.bitmap)
            {
                spec.bitmap = LoadBitmapFromFile(ResolveAssetPath(spec.asset_name));
            }
        }
    }
}

void NativeSplashOverlay::DiscardDeviceResources()
{
    for (auto &spec : avatars_)
    {
        spec.bitmap.Reset();
    }
    stroke_brush_.Reset();
    placeholder_brush_.Reset();
    white_brush_.Reset();
    render_target_.Reset();
}

ComPtr<ID2D1Bitmap> NativeSplashOverlay::LoadBitmapFromFile(const std::wstring &path)
{
    if (!wic_factory_ || !render_target_)
        return nullptr;

    ComPtr<IWICBitmapDecoder> decoder;
    if (FAILED(wic_factory_->CreateDecoderFromFilename(
            path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnLoad, &decoder)))
    {
        return nullptr;
    }

    ComPtr<IWICBitmapFrameDecode> frame;
    if (FAILED(decoder->GetFrame(0, &frame)))
        return nullptr;

    ComPtr<IWICFormatConverter> converter;
    if (FAILED(wic_factory_->CreateFormatConverter(&converter)))
        return nullptr;

    if (FAILED(converter->Initialize(
            frame.Get(), GUID_WICPixelFormat32bppPBGRA,
            WICBitmapDitherTypeNone, nullptr, 0.0, WICBitmapPaletteTypeCustom)))
    {
        return nullptr;
    }

    ComPtr<ID2D1Bitmap> bitmap;
    render_target_->CreateBitmapFromWicBitmap(converter.Get(), nullptr, &bitmap);
    return bitmap;
}

std::wstring NativeSplashOverlay::ResolveAssetPath(const std::wstring &relative_asset_path) const
{
    wchar_t exe_path[MAX_PATH]{};
    GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
    std::wstring dir(exe_path);
    size_t slash = dir.find_last_of(L"\\/");
    if (slash != std::wstring::npos)
    {
        dir = dir.substr(0, slash);
    }

    std::wstring flutter_asset = dir + L"\\data\\flutter_assets\\" + relative_asset_path;
    if (GetFileAttributesW(flutter_asset.c_str()) != INVALID_FILE_ATTRIBUTES)
    {
        return flutter_asset;
    }
    return dir + L"\\" + relative_asset_path;
}

void NativeSplashOverlay::OnTimerTick()
{
    if (is_destroyed_)
        return;

    // ضبط ساعة الصفر مع أول نبضة فعلية للواجهة حتى لا يضيع أنيميشن السقوط أثناء تحميل Dart
    if (!has_started_clock_)
    {
        has_started_clock_ = true;
        QueryPerformanceCounter(&start_time_);
    }

    LARGE_INTEGER now{};
    QueryPerformanceCounter(&now);
    float elapsed_ms = static_cast<float>(now.QuadPart - start_time_.QuadPart) * 1000.0f /
                       static_cast<float>(perf_freq_.QuadPart);

    // إجمالي زمن البناء: 1200ms نزول الطبقات + 2300ms رسم النص + 750ms وقفة استقرار = 4250ms
    constexpr float kTotalSequenceMs = 4250.0f;
    if (!animation_completed_notified_ && elapsed_ms >= kTotalSequenceMs)
    {
        animation_completed_notified_ = true;
        if (on_animation_complete_)
        {
            on_animation_complete_();
        }
    }

    if (is_fading_out_)
    {
        float fade_ms = static_cast<float>(now.QuadPart - fade_start_time_.QuadPart) * 1000.0f /
                        static_cast<float>(perf_freq_.QuadPart);
        constexpr float kFadeDurationMs = 450.0f;
        float t = (std::min)(1.0f, fade_ms / kFadeDurationMs);
        BYTE alpha = static_cast<BYTE>(255.0f * (1.0f - EaseOutCubic(t)));
        SetLayeredWindowAttributes(overlay_hwnd_, 0, alpha, LWA_ALPHA);

        if (t >= 1.0f)
        {
            is_destroyed_ = true;
            KillTimer(overlay_hwnd_, kAnimTimerId);
            DestroyWindow(overlay_hwnd_);
            overlay_hwnd_ = nullptr;
            DiscardDeviceResources();
            // إرسال رسالة غير متزامنة لتحرير الكائن بأمان بعد الخروج من WndProc
            if (parent_hwnd_)
            {
                PostMessageW(parent_hwnd_, kMsgSplashDestroyed, 0, 0);
            }
            return;
        }
    }

    Render();
}

void NativeSplashOverlay::Render()
{
    InitializeDeviceResources();
    if (!render_target_ || !has_started_clock_)
        return;

    LARGE_INTEGER now{};
    QueryPerformanceCounter(&now);
    float elapsed_ms = static_cast<float>(now.QuadPart - start_time_.QuadPart) * 1000.0f /
                       static_cast<float>(perf_freq_.QuadPart);

    D2D1_SIZE_F size = render_target_->GetSize();
    float container_w = (std::min)(480.0f, size.width * 0.92f);
    float scale_factor = container_w / 480.0f;
    float avatar_base_size = 100.0f * scale_factor;
    float container_h = 150.0f * scale_factor;
    float bottom_margin = 25.0f;

    float total_block_h = container_h + bottom_margin + kLogoBoxHeight;
    float start_y = (size.height - total_block_h) * 0.5f;
    float container_left = (size.width - container_w) * 0.5f;

    render_target_->BeginDraw();
    render_target_->Clear(D2D1::ColorF(0x111111));

    for (const auto &spec : avatars_)
    {
        DrawAvatar(spec, container_left, start_y, container_w, container_h, avatar_base_size, elapsed_ms);
    }

    // يبدأ رسم النص عند 1200ms ويستغرق 2300ms
    float stroke_raw_t = (elapsed_ms - 1200.0f) / 2300.0f;
    stroke_raw_t = (std::max)(0.0f, (std::min)(1.0f, stroke_raw_t));
    float stroke_progress = EaseInOutCubic(stroke_raw_t);

    DrawSvgStroke(size.width * 0.5f, start_y + container_h + bottom_margin, stroke_progress);

    HRESULT hr = render_target_->EndDraw();
    if (hr == D2DERR_RECREATE_TARGET)
    {
        DiscardDeviceResources();
    }
}

void NativeSplashOverlay::DrawAvatar(
    const AvatarSpec &spec,
    float container_left,
    float container_top,
    float container_w,
    float container_h,
    float avatar_base_size,
    float elapsed_ms)
{
    float local_ms = elapsed_ms - spec.delay_ms;
    if (local_ms <= 0.0f)
        return;

    constexpr float kDropDurationMs = 800.0f;
    float norm_t = (std::min)(1.0f, local_ms / kDropDurationMs);

    float alpha = (std::min)(1.0f, norm_t / 0.35f);
    float scale = 0.6f + (spec.target_scale - 0.6f) * EaseOutCubic(norm_t);
    float drop_y = ComputeDropOffset(norm_t, -220.0f);

    float cx = container_left + (container_w * spec.left_percent);
    float cy = container_top + (container_h * 0.5f) + drop_y;
    float radius = (avatar_base_size * 0.5f) * scale;

    // 1. رسم الظل الساقط المتدرج خلف الدائرة
    ComPtr<ID2D1GradientStopCollection> stops;
    D2D1_GRADIENT_STOP grad_stops[2]{
        {0.0f, D2D1::ColorF(0.0f, 0.0f, 0.0f, 0.58f * alpha)},
        {1.0f, D2D1::ColorF(0.0f, 0.0f, 0.0f, 0.0f)},
    };
    if (SUCCEEDED(render_target_->CreateGradientStopCollection(grad_stops, 2, &stops)))
    {
        ComPtr<ID2D1RadialGradientBrush> shadow_brush;
        float shadow_r = radius * 1.18f;
        D2D1_POINT_2F shadow_center = D2D1::Point2F(cx, cy + spec.shadow_offset);
        if (SUCCEEDED(render_target_->CreateRadialGradientBrush(
                D2D1::RadialGradientBrushProperties(shadow_center, D2D1::Point2F(0, 0), shadow_r, shadow_r),
                stops.Get(),
                &shadow_brush)))
        {
            render_target_->FillEllipse(D2D1::Ellipse(shadow_center, shadow_r, shadow_r), shadow_brush.Get());
        }
    }

    // 2. قناع القص الدائري للصورة (Center-Crop)
    ComPtr<ID2D1EllipseGeometry> clip_geom;
    D2D1_ELLIPSE ellipse = D2D1::Ellipse(D2D1::Point2F(cx, cy), radius, radius);
    if (SUCCEEDED(d2d_factory_->CreateEllipseGeometry(ellipse, &clip_geom)))
    {
        ComPtr<ID2D1Layer> layer;
        if (SUCCEEDED(render_target_->CreateLayer(&layer)))
        {
            D2D1_LAYER_PARAMETERS layer_params = D2D1::LayerParameters(
                D2D1::RectF(cx - radius, cy - radius, cx + radius, cy + radius),
                clip_geom.Get(),
                D2D1_ANTIALIAS_MODE_PER_PRIMITIVE,
                D2D1::IdentityMatrix(),
                alpha);

            render_target_->PushLayer(layer_params, layer.Get());
            render_target_->FillEllipse(ellipse, placeholder_brush_.Get());

            if (spec.bitmap)
            {
                D2D1_SIZE_F bmp_size = spec.bitmap->GetSize();
                float diameter = radius * 2.0f;
                float img_scale = (std::max)(diameter / bmp_size.width, diameter / bmp_size.height);
                float draw_w = bmp_size.width * img_scale;
                float draw_h = bmp_size.height * img_scale;
                D2D1_RECT_F dest = D2D1::RectF(
                    cx - draw_w * 0.5f,
                    cy - draw_h * 0.5f,
                    cx + draw_w * 0.5f,
                    cy + draw_h * 0.5f);
                render_target_->DrawBitmap(spec.bitmap.Get(), dest, 1.0f,
                                           D2D1_BITMAP_INTERPOLATION_MODE_LINEAR);
            }
            render_target_->PopLayer();
        }
    }

    // 3. الإطار الأبيض العازل حول الدائرة
    float border_w = 4.0f * scale;
    white_brush_->SetOpacity(alpha);
    render_target_->DrawEllipse(
        D2D1::Ellipse(D2D1::Point2F(cx, cy), radius - border_w * 0.5f, radius - border_w * 0.5f),
        white_brush_.Get(),
        border_w);
}

void NativeSplashOverlay::DrawSvgStroke(float center_x, float top_y, float progress)
{
    if (progress <= 0.0f || total_svg_length_ <= 0.0f || svg_contours_.empty())
        return;

    float left_x = center_x - (kLogoBoxWidth * 0.5f);
    D2D1::Matrix3x2F prev_transform;
    render_target_->GetTransform(&prev_transform);
    render_target_->SetTransform(D2D1::Matrix3x2F::Translation(left_x, top_y) * prev_transform);

    ComPtr<ID2D1StrokeStyle> round_style;
    D2D1_STROKE_STYLE_PROPERTIES sp = D2D1::StrokeStyleProperties(
        D2D1_CAP_STYLE_ROUND, D2D1_CAP_STYLE_ROUND, D2D1_CAP_STYLE_ROUND, D2D1_LINE_JOIN_ROUND);
    d2d_factory_->CreateStrokeStyle(sp, nullptr, 0, &round_style);

    float remaining = total_svg_length_ * progress;
    for (const auto &c : svg_contours_)
    {
        if (remaining <= 0.0f)
            break;
        if (c.points.size() < 2)
            continue;

        ComPtr<ID2D1PathGeometry> partial_geom;
        ComPtr<ID2D1GeometrySink> sink;
        if (SUCCEEDED(d2d_factory_->CreatePathGeometry(&partial_geom)) &&
            SUCCEEDED(partial_geom->Open(&sink)))
        {
            sink->BeginFigure(c.points[0], D2D1_FIGURE_BEGIN_HOLLOW);
            for (size_t i = 0; i < c.seg_lengths.size() && remaining > 0.0f; ++i)
            {
                float seg_len = c.seg_lengths[i];
                if (remaining >= seg_len)
                {
                    sink->AddLine(c.points[i + 1]);
                    remaining -= seg_len;
                }
                else
                {
                    float ratio = (seg_len > 0.0f) ? (remaining / seg_len) : 0.0f;
                    D2D1_POINT_2F mid = D2D1::Point2F(
                        c.points[i].x + (c.points[i + 1].x - c.points[i].x) * ratio,
                        c.points[i].y + (c.points[i + 1].y - c.points[i].y) * ratio);
                    sink->AddLine(mid);
                    remaining = 0.0f;
                }
            }
            sink->EndFigure(D2D1_FIGURE_END_OPEN);
            sink->Close();
            render_target_->DrawGeometry(
                partial_geom.Get(), stroke_brush_.Get(), kStrokeWidth, round_style.Get());
        }
    }

    render_target_->SetTransform(prev_transform);
}

float NativeSplashOverlay::EaseInOutCubic(float t)
{
    return (t < 0.5f) ? (4.0f * t * t * t) : (1.0f - std::pow(-2.0f * t + 2.0f, 3.0f) * 0.5f);
}

float NativeSplashOverlay::EaseOutCubic(float t)
{
    float inv = 1.0f - t;
    return 1.0f - (inv * inv * inv);
}

float NativeSplashOverlay::ComputeDropOffset(float norm_t, float drop_height)
{
    if (norm_t <= 0.55f)
    {
        float p = norm_t / 0.55f;
        return drop_height * (1.0f - p * p);
    }
    if (norm_t <= 0.75f)
    {
        float p = (norm_t - 0.55f) / 0.20f;
        return -22.0f * std::sin(p * 3.14159265f);
    }
    if (norm_t <= 0.90f)
    {
        return 0.0f;
    }
    if (norm_t <= 0.96f)
    {
        float p = (norm_t - 0.90f) / 0.06f;
        return -6.0f * std::sin(p * 3.14159265f);
    }
    return 0.0f;
}