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
