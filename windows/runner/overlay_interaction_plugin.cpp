#include "overlay_interaction_plugin.h"

#include <dwmapi.h>
#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cmath>
#include <memory>
#include <optional>
#include <string>

namespace {

constexpr UINT_PTR kHoverTimerId = 0x504F4532;
constexpr UINT kHoverIntervalMs = 40;

// Keep this HWND on window_manager's transparent layered-window path. Frost is painted by Flutter;
// changing the DWM backdrop or accent policy here breaks the overlay's per-pixel transparency.
// DWMWA_BORDER_COLOR is not in every SDK header this project builds against, so it is defined here
// by its documented value. Only Windows 11 honours it; older versions ignore the call, which is why
// the Flutter-drawn border is hidden independently of it.
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

constexpr DWORD kDwmColorDefault = 0xFFFFFFFF;
constexpr DWORD kDwmColorNone = 0xFFFFFFFE;

double Number(const flutter::EncodableMap& arguments, const char* key) {
  const auto found = arguments.find(flutter::EncodableValue(key));
  if (found == arguments.end()) {
    return 0;
  }
  if (const auto* value = std::get_if<double>(&found->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int32_t>(&found->second)) {
    return static_cast<double>(*value);
  }
  if (const auto* value = std::get_if<int64_t>(&found->second)) {
    return static_cast<double>(*value);
  }
  return 0;
}

class OverlayInteractionPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(),
            "poe2_loot_tracker/overlay_interaction",
            &flutter::StandardMethodCodec::GetInstance());
    auto plugin = std::make_unique<OverlayInteractionPlugin>(registrar);
    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });
    registrar->AddPlugin(std::move(plugin));
  }

  explicit OverlayInteractionPlugin(
      flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        window_(::GetAncestor(registrar->GetView()->GetNativeWindow(),
                             GA_ROOT)) {
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleWindowProc(hwnd, message, wparam, lparam);
        });
  }

  ~OverlayInteractionPlugin() override {
    if (window_ != nullptr) {
      ::KillTimer(window_, kHoverTimerId);
      SetTransparent(false, true);
    }
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "setClickThrough") {
      const auto* arguments =
          std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments == nullptr) {
        result->Error("bad-arguments", "setClickThrough expects a map");
        return;
      }
      const auto enabled_value =
          arguments->find(flutter::EncodableValue("enabled"));
      enabled_ = enabled_value != arguments->end() &&
                 std::get_if<bool>(&enabled_value->second) != nullptr &&
                 std::get<bool>(enabled_value->second);
      top_ = Number(*arguments, "top");
      right_ = Number(*arguments, "right");
      width_ = Number(*arguments, "width");
      height_ = Number(*arguments, "height");

      if (enabled_) {
        ::SetTimer(window_, kHoverTimerId, kHoverIntervalMs, nullptr);
        UpdateTransparency();
      } else {
        ::KillTimer(window_, kHoverTimerId);
        SetTransparent(false, true);
      }
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (call.method_name() == "setAlwaysOnTop") {
      const auto* enabled = std::get_if<bool>(call.arguments());
      if (enabled == nullptr) {
        result->Error("bad-arguments", "setAlwaysOnTop expects a boolean");
        return;
      }
      const BOOL changed = ::SetWindowPos(
          window_, *enabled ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
          SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
      if (changed == FALSE) {
        result->Error("set-window-pos-failed",
                      "Windows could not update the overlay z-order");
        return;
      }
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (call.method_name() == "setTransparentBorder") {
      const auto* enabled = std::get_if<bool>(call.arguments());
      if (enabled == nullptr) {
        result->Error("bad-arguments", "setTransparentBorder expects a boolean");
        return;
      }
      const DWORD color = *enabled ? kDwmColorNone : kDwmColorDefault;
      // DWMWA_BORDER_COLOR is supported by Windows 11. The Flutter border is still hidden on
      // older versions, so lack of native support does not make the setting unusable.
      ::DwmSetWindowAttribute(window_, DWMWA_BORDER_COLOR, &color,
                              sizeof(color));
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (call.method_name() == "ensureVisible") {
      if (::IsIconic(window_)) {
        ::ShowWindow(window_, SW_RESTORE);
      } else {
        ::ShowWindow(window_, SW_SHOWNOACTIVATE);
      }
      ::SetWindowPos(window_, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                         SWP_NOACTIVATE | SWP_SHOWWINDOW);
      result->Success(
          flutter::EncodableValue(::IsWindowVisible(window_) != FALSE));
      return;
    }

    result->NotImplemented();
  }

  std::optional<LRESULT> HandleWindowProc(HWND, UINT message, WPARAM wparam,
                                          LPARAM) {
    if (enabled_ && message == WM_TIMER && wparam == kHoverTimerId) {
      UpdateTransparency();
      return 0;
    }
    return std::nullopt;
  }

  void UpdateTransparency() {
    if (!enabled_ || window_ == nullptr) {
      return;
    }

    POINT cursor{};
    RECT client{};
    if (!::GetCursorPos(&cursor) || !::ScreenToClient(window_, &cursor) ||
        !::GetClientRect(window_, &client)) {
      SetTransparent(true, false);
      return;
    }

    const double scale =
        static_cast<double>(::GetDpiForWindow(window_)) / USER_DEFAULT_SCREEN_DPI;
    const LONG left = client.right -
                      static_cast<LONG>(std::ceil((right_ + width_) * scale));
    const LONG right =
        client.right - static_cast<LONG>(std::floor(right_ * scale));
    const LONG top = static_cast<LONG>(std::floor(top_ * scale));
    const LONG bottom = static_cast<LONG>(std::ceil((top_ + height_) * scale));
    const bool over_controls = cursor.x >= left && cursor.x < right &&
                               cursor.y >= top && cursor.y < bottom;
    SetTransparent(!over_controls, false);
  }

  void SetTransparent(bool transparent, bool clear_layered) {
    if (window_ == nullptr ||
        (transparent == transparent_ && !clear_layered)) {
      return;
    }
    LONG_PTR style = ::GetWindowLongPtr(window_, GWL_EXSTYLE);
    if (transparent) {
      style |= WS_EX_TRANSPARENT | WS_EX_LAYERED;
    } else {
      style &= ~WS_EX_TRANSPARENT;
      if (clear_layered) {
        style &= ~WS_EX_LAYERED;
      }
    }
    ::SetWindowLongPtr(window_, GWL_EXSTYLE, style);
    transparent_ = transparent;
  }

  flutter::PluginRegistrarWindows* registrar_;
  HWND window_ = nullptr;
  int window_proc_id_ = -1;
  bool enabled_ = false;
  bool transparent_ = false;
  double top_ = 0;
  double right_ = 0;
  double width_ = 0;
  double height_ = 0;
};

}  // namespace

void RegisterOverlayInteractionPlugin(flutter::PluginRegistry* registry) {
  const auto registrar_ref =
      registry->GetRegistrarForPlugin("OverlayInteractionPlugin");
  OverlayInteractionPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar_ref));
}
