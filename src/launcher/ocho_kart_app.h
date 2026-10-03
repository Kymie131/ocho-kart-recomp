// ocho_kart - ReXGlue Recompiled Project
//
// Pre-boot launcher. Overrides OnFinalizePaths to pause startup, show the
// options dialog, and resume once the player confirms. Options are applied to
// the cvars (user_language, launcher_button_icons) before the XEX loads.
//
// This file is written once by codegen (RegeneratePolicy::FirstInitOnly) and
// preserved afterwards, so it is safe to edit here and to keep a copy in git.

#pragma once

#include <rex/rex_app.h>
#include <rex/cvar.h>
#include <rex/ui/imgui_dialog.h>

#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <string>

#include <imgui.h>

namespace {

// Language ids match XLanguage: 1 English, 5 Spanish (Mexico), 7 Spanish
// (neutral), 9 Portuguese.
struct LauncherOption {
  const char* label;
  int language_id;
};

inline const LauncherOption* launcher_languages() {
  static const LauncherOption kLanguages[] = {
      {"Espanol (Mexico)", 5},
      {"Espanol (neutro)", 7},
      {"English", 1},
      {"Portugues", 9},
  };
  return kLanguages;
}

inline const char* const* launcher_icon_names() {
  static const char* kNames[] = {"Auto", "Xbox", "PlayStation", "Nintendo"};
  return kNames;
}

inline const char* const* launcher_icon_values() {
  static const char* kValues[] = {"auto", "xbox", "playstation", "nintendo"};
  return kValues;
}

struct LauncherState {
  int language = 0;  // index into launcher_languages()
  int icons = 0;     // index into launcher_icon_names()
  char dump[512] = {};
  bool accepted = false;
  bool cancelled = false;
  bool loaded = false;
};

inline LauncherState& launcher_state() {
  static LauncherState s;
  return s;
}

// Reads user_language and launcher_button_icons back into the UI state so the
// launcher reflects the last saved config on the next start.
inline void launcher_load_from_cvars() {
  auto& st = launcher_state();
  if (st.loaded) {
    return;
  }
  st.loaded = true;

  int lang_id = 5;
  if (const auto* info = rex::cvar::GetFlagInfo("user_language")) {
    (void)info;
    lang_id = std::atoi(rex::cvar::GetFlagByName("user_language").c_str());
  }
  const LauncherOption* langs = launcher_languages();
  for (int i = 0; i < 4; ++i) {
    if (langs[i].language_id == lang_id) {
      st.language = i;
      break;
    }
  }

  std::string icons = rex::cvar::GetFlagByName("launcher_button_icons");
  const char* const* values = launcher_icon_values();
  for (int i = 0; i < 4; ++i) {
    if (icons == values[i]) {
      st.icons = i;
      break;
    }
  }
}

// Draws the four face buttons for the selected prompt style. Shapes are drawn
// with the ImGui draw list (no game assets). Style id matches launcher_icons:
// 0 auto (shows Xbox), 1 xbox, 2 playstation, 3 nintendo.
inline void launcher_draw_button_preview(int style, float size) {
  ImDrawList* dl = ImGui::GetWindowDrawList();
  const ImVec2 origin = ImGui::GetCursorScreenPos();
  const float r = size * 0.5f;
  const float gap = size * 1.35f;
  const float cx = origin.x + r;
  const float cy = origin.y + r;
  const ImU32 text_col = ImGui::GetColorU32(ImGuiCol_Text);

  struct Face {
    float x;
    float y;
    const char* label;
    ImU32 color;
  };

  // Xbox colors: A green, B red, X blue, Y yellow.
  const ImU32 kGreen = IM_COL32(0x10, 0x7C, 0x10, 255);
  const ImU32 kRed = IM_COL32(0xC0, 0x30, 0x30, 255);
  const ImU32 kBlue = IM_COL32(0x20, 0x60, 0xC0, 255);
  const ImU32 kYellow = IM_COL32(0xC0, 0xA0, 0x10, 255);
  const ImU32 kGray = IM_COL32(0x60, 0x60, 0x60, 255);

  if (style == 2) {
    // PlayStation: cross, circle, square, triangle (grayscale).
    struct Pos {
      float x;
      float y;
      int shape;
    };
    const Pos ps[4] = {{0, 0, 0}, {1, 0, 1}, {0, 1, 2}, {1, 1, 3}};
    for (const auto& p : ps) {
      const float px = cx + p.x * gap;
      const float py = cy + p.y * gap;
      if (p.shape == 0) {
        dl->AddLine(ImVec2(px - r * 0.6f, py - r * 0.6f),
                    ImVec2(px + r * 0.6f, py + r * 0.6f), text_col, 2.0f);
        dl->AddLine(ImVec2(px - r * 0.6f, py + r * 0.6f),
                    ImVec2(px + r * 0.6f, py - r * 0.6f), text_col, 2.0f);
      } else if (p.shape == 1) {
        dl->AddCircle(ImVec2(px, py), r * 0.7f, text_col, 0, 2.0f);
      } else if (p.shape == 2) {
        dl->AddRect(ImVec2(px - r * 0.6f, py - r * 0.6f),
                    ImVec2(px + r * 0.6f, py + r * 0.6f), text_col, 0.0f, 0, 2.0f);
      } else {
        dl->AddTriangle(ImVec2(px, py - r * 0.7f), ImVec2(px - r * 0.7f, py + r * 0.6f),
                        ImVec2(px + r * 0.7f, py + r * 0.6f), text_col, 2.0f);
      }
    }
  } else {
    // Xbox (style 1) and Nintendo (style 3), always A/B/X/Y. Nintendo swaps the
    // face positions (B/A on the bottom, Y/X on the top), matching its layout.
    const bool nint =
        (style == 3);
    // Xbox: A bottom, B right, X left, Y top. Nintendo: B bottom, A right,
    // Y left, X top.
    const Face faces[4] = {
        {0, 1, nint ? "B" : "A", nint ? kRed : kGreen},    // bottom
        {1, 0, nint ? "A" : "B", nint ? kGreen : kRed},    // right
        {-1, 0, nint ? "Y" : "X", nint ? kYellow : kBlue}, // left
        {0, -1, nint ? "X" : "Y", nint ? kBlue : kYellow}, // top
    };
    for (const auto& f : faces) {
      const float px = cx + f.x * gap;
      const float py = cy + f.y * gap;
      dl->AddCircleFilled(ImVec2(px, py), r, f.color, 0);
      const ImVec2 ts = ImGui::CalcTextSize(f.label);
      dl->AddText(ImVec2(px - ts.x * 0.5f, py - ts.y * 0.5f), IM_COL32(255, 255, 255, 255),
                  f.label);
    }
  }
  (void)kGray;

  // Shoulder buttons and triggers below the face buttons. Labels differ per
  // platform: Xbox LB/RB + LT/RT, PlayStation L1/R1 + L2/R2, Nintendo L/R + ZL/ZR.
  const char* bl;
  const char* br;
  const char* tl;
  const char* tr;
  if (style == 2) {
    bl = "L1";
    br = "R1";
    tl = "L2";
    tr = "R2";
  } else if (style == 3) {
    bl = "L";
    br = "R";
    tl = "ZL";
    tr = "ZR";
  } else {
    bl = "LB";
    br = "RB";
    tl = "LT";
    tr = "RT";
  }

  const float shoulder_w = size * 1.5f;
  const float shoulder_h = size * 0.8f;
  const float shoulder_y = origin.y + gap * 2 + size * 0.4f;
  const float left_x = origin.x;
  const float right_x = origin.x + gap * 2;
  struct Shoulder {
    float x;
    float y;
    const char* label;
    ImU32 color;
  };
  const Shoulder shoulders[4] = {
      {left_x, shoulder_y - shoulder_h * 1.3f, bl, kGray},
      {right_x, shoulder_y - shoulder_h * 1.3f, br, kGray},
      {left_x, shoulder_y, tl, IM_COL32(0x50, 0x50, 0x50, 255)},
      {right_x, shoulder_y, tr, IM_COL32(0x50, 0x50, 0x50, 255)},
  };
  for (const auto& s : shoulders) {
    dl->AddRectFilled(ImVec2(s.x, s.y), ImVec2(s.x + shoulder_w, s.y + shoulder_h), s.color,
                      3.0f);
    const ImVec2 ts = ImGui::CalcTextSize(s.label);
    dl->AddText(ImVec2(s.x + (shoulder_w - ts.x) * 0.5f, s.y + (shoulder_h - ts.y) * 0.5f),
                IM_COL32(255, 255, 255, 255), s.label);
  }

  // Stick clicks (L3/R3), a d-pad, and the system buttons below the shoulders.
  const float sys_y = shoulder_y + shoulder_h * 2.2f;
  const ImU32 body = IM_COL32(0x45, 0x45, 0x45, 255);

  auto draw_pill = [&](float x, float y, float w, const char* label) {
    dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + shoulder_h), body, 3.0f);
    const ImVec2 ts = ImGui::CalcTextSize(label);
    dl->AddText(ImVec2(x + (w - ts.x) * 0.5f, y + (shoulder_h - ts.y) * 0.5f),
                IM_COL32(255, 255, 255, 255), label);
  };

  // Stick clicks.
  draw_pill(origin.x, sys_y, size * 0.9f, "L3");
  draw_pill(origin.x + gap * 2, sys_y, size * 0.9f, "R3");

  // D-pad (cross of four squares) in the middle.
  const float dpad_cx = origin.x + gap + r * 0.5f;
  const float dpad_cy = sys_y + shoulder_h * 0.5f;
  const float q = size * 0.42f;
  const float t = size * 0.32f;
  dl->AddRectFilled(ImVec2(dpad_cx - t * 0.5f, dpad_cy - t * 1.5f),
                    ImVec2(dpad_cx + t * 0.5f, dpad_cy - t * 0.5f), q ? body : body, 2.0f);
  dl->AddRectFilled(ImVec2(dpad_cx - t * 0.5f, dpad_cy + t * 0.5f),
                    ImVec2(dpad_cx + t * 0.5f, dpad_cy + t * 1.5f), body, 2.0f);
  dl->AddRectFilled(ImVec2(dpad_cx - t * 1.5f, dpad_cy - t * 0.5f),
                    ImVec2(dpad_cx - t * 0.5f, dpad_cy + t * 0.5f), body, 2.0f);
  dl->AddRectFilled(ImVec2(dpad_cx + t * 0.5f, dpad_cy - t * 0.5f),
                    ImVec2(dpad_cx + t * 1.5f, dpad_cy + t * 0.5f), body, 2.0f);
  (void)q;

  // System buttons: View/Menu/Guide (Xbox), Share/Options/PS (PS), -/+/Home (Nintendo).
  const char* sys1;
  const char* sys2;
  const char* sys3;
  if (style == 2) {
    sys1 = "Share";
    sys2 = "Options";
    sys3 = "PS";
  } else if (style == 3) {
    sys1 = "-";
    sys2 = "+";
    sys3 = "Home";
  } else {
    sys1 = "View";
    sys2 = "Menu";
    sys3 = "Guide";
  }
  const float sys_row_y = sys_y + shoulder_h * 1.4f;
  const float sys_w = size * 1.1f;
  draw_pill(origin.x, sys_row_y, sys_w, sys1);
  draw_pill(origin.x + gap * 2, sys_row_y, sys_w, sys2);
  draw_pill(origin.x + gap * 0.9f, sys_row_y, sys_w, sys3);

  ImGui::Dummy(ImVec2(gap * 2 + shoulder_w,
                      gap * 2 + size * 0.4f + shoulder_h * 2.3f + shoulder_h * 2.0f));
}

}  // namespace

class LauncherDialog : public rex::ui::ImGuiDialog {
 public:
  LauncherDialog(rex::ui::ImGuiDrawer* drawer, std::function<void()> on_accept,
                 std::function<void()> on_cancel)
      : rex::ui::ImGuiDialog(drawer),
        on_accept_(std::move(on_accept)),
        on_cancel_(std::move(on_cancel)) {}

 protected:
  void OnDraw(ImGuiIO& io) override {
    (void)io;
    auto& st = launcher_state();

    const ImGuiViewport* vp = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(vp->GetCenter(), ImGuiCond_Always, ImVec2(0.5f, 0.5f));
    ImGui::SetNextWindowSize(ImVec2(460, 0), ImGuiCond_Always);
    if (ImGui::Begin("El Chavo Kart - Launcher", nullptr,
                     ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize |
                         ImGuiWindowFlags_AlwaysAutoResize)) {
      ImGui::TextUnformatted("Choose your options, then press Play.");
      ImGui::Separator();

      ImGui::TextUnformatted("Language");
      const LauncherOption* langs = launcher_languages();
      for (int i = 0; i < 4; ++i) {
        if (ImGui::RadioButton(langs[i].label, st.language == i)) {
          st.language = i;
        }
      }

      ImGui::Separator();
      ImGui::TextUnformatted("Controller button icons");
      const char* const* icon_names = launcher_icon_names();
      for (int i = 0; i < 4; ++i) {
        if (ImGui::RadioButton(icon_names[i], st.icons == i)) {
          st.icons = i;
        }
      }
      ImGui::Separator();
      launcher_draw_button_preview(st.icons, ImGui::GetFontSize() * 0.7f);

      ImGui::Separator();
      ImGui::TextUnformatted("Game folder (with default.xex)");
      ImGui::SetNextItemWidth(-1.0f);
      ImGui::InputText("##dump", st.dump, sizeof(st.dump));

      ImGui::Separator();
      if (ImGui::Button("Play", ImVec2(140, 0))) {
        st.accepted = true;
        Accept();
      }
      ImGui::SameLine();
      if (ImGui::Button("Quit", ImVec2(140, 0))) {
        st.cancelled = true;
        Cancel();
      }
    }
    ImGui::End();
  }

 private:
  void Accept() {
    auto& st = launcher_state();
    int lang_id = launcher_languages()[st.language].language_id;
    const char* icon = launcher_icon_values()[st.icons];
    rex::cvar::SetFlagByName("user_language", std::to_string(lang_id));
    rex::cvar::SetFlagByName("launcher_button_icons", icon);
    auto cb = on_accept_;
    Close();
    if (cb) {
      cb();
    }
  }

  void Cancel() {
    auto cb = on_cancel_;
    Close();
    if (cb) {
      cb();
    }
  }

  std::function<void()> on_accept_;
  std::function<void()> on_cancel_;
};

class OchoKartApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<OchoKartApp>(new OchoKartApp(ctx, "ocho_kart",
        PPCImageConfig));
  }

  // Pause startup until the player confirms the launcher. The event loop keeps
  // running, so the dialog renders; resume() continues initialization.
  std::optional<rex::PathConfig> OnFinalizePaths(
      const rex::PathConfig& defaults,
      std::function<void(rex::PathConfig)> resume) override {
    launcher_load_from_cvars();
    auto& st = launcher_state();
    if (st.dump[0] == '\0') {
      std::string current = defaults.game_data_root.string();
      std::snprintf(st.dump, sizeof(st.dump), "%s", current.c_str());
    }

    resume_ = std::move(resume);
    defaults_ = defaults;

    auto* drawer = imgui_drawer();
    if (!drawer) {
      // No UI available; continue with defaults.
      return defaults;
    }

    launcher_dialog_ = std::make_unique<LauncherDialog>(
        drawer,
        [this]() {
          rex::PathConfig paths = defaults_;
          auto& s = launcher_state();
          paths.game_data_root = std::filesystem::path(s.dump);
          // Persist the launcher choices so the next start remembers them.
          if (!paths.config_path.empty()) {
            rex::cvar::SaveConfig(paths.config_path);
          }
          auto resume = resume_;
          resume_ = nullptr;
          if (resume) {
            resume(paths);
          }
        },
        [this]() {
          if (window()) {
            window()->RequestClose();
          }
        });

    return std::nullopt;
  }

 private:
  std::unique_ptr<LauncherDialog> launcher_dialog_;
  std::function<void(rex::PathConfig)> resume_;
  rex::PathConfig defaults_;
};
