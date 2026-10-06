// FMOD / UE3-FMODAudio diagnostics for El Chavo Kart.
//
// Strong overrides of weak generated guest functions (REX_HOOK_RAW). Each hook
// calls the original (__imp__sub_XXXXXXXX) and, when --fmod_diag=true, logs the
// arguments and FMOD_RESULT so one traced run shows where the title's audio
// path stops (EventSystem init, FEV load, bank open, loading sets, cues).
// With the cvar off the hooks are pass-through.
//
// Addresses come from the decrypted image; see docs/audio-restart.md
// ("Ruta FMOD del título").

#include <atomic>
#include <cstdint>
#include <cstring>
#include <string>

#include <rex/cvar.h>
#include <rex/hook.h>
#include <rex/logging.h>

REXCVAR_DEFINE_BOOL(fmod_diag, false, "Audio",
                    "Log the title's FMOD calls (init, FEV load, bank opens, loading sets)");

namespace {

constexpr int kMaxPerHook = 200;

inline uint32_t be32(const uint8_t* base, uint32_t addr) {
  uint32_t v;
  std::memcpy(&v, base + addr, 4);
  return __builtin_bswap32(v);
}

inline bool plausible(uint32_t addr) { return addr >= 0x10000 && addr < 0xF0000000; }

std::string ansi(const uint8_t* base, uint32_t addr, size_t max = 200) {
  if (!plausible(addr)) return addr ? "<bad ptr>" : "<null>";
  std::string s;
  for (size_t i = 0; i < max; ++i) {
    char c = static_cast<char>(base[addr + i]);
    if (!c) break;
    s.push_back((c >= 32 && c < 127) ? c : '?');
  }
  return s;
}

std::string wide(const uint8_t* base, uint32_t addr, size_t max = 200) {
  if (!plausible(addr)) return addr ? "<bad ptr>" : "<null>";
  std::string s;
  for (size_t i = 0; i < max; ++i) {
    uint16_t c = static_cast<uint16_t>((base[addr + 2 * i] << 8) | base[addr + 2 * i + 1]);
    if (!c) break;
    s.push_back((c >= 32 && c < 127) ? static_cast<char>(c) : '?');
  }
  return s;
}

bool budget(std::atomic<int>& n) {
  if (!REXCVAR_GET(fmod_diag)) return false;
  return n.fetch_add(1, std::memory_order_relaxed) < kMaxPerHook;
}

constexpr uint32_t kEventSystemGlobal = 0x83CE3694;
constexpr uint32_t kFmodDisableGlobal = 0x83CE3698;  // PostLoad requires == 0
constexpr uint32_t kGEngine = 0x83CE2624;

}  // namespace

#define DIAG_IMP(name) REX_EXTERN(__imp__##name);

DIAG_IMP(sub_82A2D890)  // UFMODAudioDevice::Init
DIAG_IMP(sub_82A2D6A0)  // FMOD EventSystem create + System setup
DIAG_IMP(sub_82F98810)  // FMOD::EventSystem_Create(&out)
DIAG_IMP(sub_82F9A3F8)  // EventSystem::init(maxchannels, flags, extra, eventflags)
DIAG_IMP(sub_82A2BF80)  // UFMODProject::PostLoad
DIAG_IMP(sub_82F9A4D0)  // EventSystem::setMediaPath(path)
DIAG_IMP(sub_82F9A7B0)  // EventSystem::load(data, loadinfo, &project)
DIAG_IMP(sub_82A2BC48)  // UFMODProject: store project handle
DIAG_IMP(sub_82A23A48)  // FMOD error-check helper (result, expr, ctx, file, line)
DIAG_IMP(sub_82A2D330)  // FMOD file-system open callback
DIAG_IMP(sub_82A2C7F8)  // UFMODSoundBank::Serialize
DIAG_IMP(sub_82A387E0)  // UFMODLoadingSet::LoadInternal
DIAG_IMP(sub_82A386E0)  // UFMODLoadingSet::AttemptUnloadInternal
DIAG_IMP(sub_82A35530)  // UFMODMusicSystem::execPromptCue
DIAG_IMP(sub_82A35E30)  // UFMODEventComponent::execPlay
DIAG_IMP(sub_8232EED8)  // appFailAssert-style logger (expr, file, line, fmt, ...)

REX_HOOK_RAW(sub_82A2D890) {
  static std::atomic<int> n{0};
  uint32_t self = ctx.r3.u32;
  __imp__sub_82A2D890(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG AudioDevice::Init this={:08X} -> {} EventSystem={:08X}", self,
                ctx.r3.u32, be32(base, kEventSystemGlobal));
}

REX_HOOK_RAW(sub_82A2D6A0) {
  static std::atomic<int> n{0};
  __imp__sub_82A2D6A0(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG FMOD setup (EventSystem_Create..setLanguage) -> {} EventSystem={:08X}",
                ctx.r3.u32, be32(base, kEventSystemGlobal));
}

REX_HOOK_RAW(sub_82F98810) {
  static std::atomic<int> n{0};
  __imp__sub_82F98810(ctx, base);
  if (budget(n)) REXAPU_INFO("FMODDIAG EventSystem_Create -> {}", static_cast<int32_t>(ctx.r3.u32));
}

REX_HOOK_RAW(sub_82F9A3F8) {
  static std::atomic<int> n{0};
  uint32_t ch = ctx.r4.u32, flags = ctx.r5.u32;
  __imp__sub_82F9A3F8(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG EventSystem::init(ch={}, flags={:#x}) -> {}", ch, flags,
                static_cast<int32_t>(ctx.r3.u32));
}

REX_HOOK_RAW(sub_82A2BF80) {
  static std::atomic<int> n{0};
  uint32_t self = ctx.r3.u32;
  if (budget(n)) {
    uint32_t engine = be32(base, kGEngine);
    uint32_t client = plausible(engine) ? be32(base, engine + 0x4B0) : 0;
    REXAPU_INFO("FMODDIAG UFMODProject::PostLoad this={:08X} EventSystem={:08X} disable={:08X} "
                "GEngine={:08X} client={:08X}",
                self, be32(base, kEventSystemGlobal), be32(base, kFmodDisableGlobal), engine,
                client);
  }
  __imp__sub_82A2BF80(ctx, base);
}

REX_HOOK_RAW(sub_82F9A4D0) {
  static std::atomic<int> n{0};
  std::string path = REXCVAR_GET(fmod_diag) ? ansi(base, ctx.r4.u32) : std::string();
  __imp__sub_82F9A4D0(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG EventSystem::setMediaPath('{}') -> {}", path,
                static_cast<int32_t>(ctx.r3.u32));
}

REX_HOOK_RAW(sub_82F9A7B0) {
  static std::atomic<int> n{0};
  uint32_t data = ctx.r4.u32, info = ctx.r5.u32, out = ctx.r6.u32;
  uint32_t len = plausible(info) ? be32(base, info + 0x0C) : 0;
  __imp__sub_82F9A7B0(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG EventSystem::load(data={:08X}, len={}) -> {} project={:08X}", data, len,
                static_cast<int32_t>(ctx.r3.u32), plausible(out) ? be32(base, out) : 0);
}

REX_HOOK_RAW(sub_82A2BC48) {
  static std::atomic<int> n{0};
  if (budget(n))
    REXAPU_INFO("FMODDIAG UFMODProject store handle this={:08X} r4={:08X}", ctx.r3.u32, ctx.r4.u32);
  __imp__sub_82A2BC48(ctx, base);
}

REX_HOOK_RAW(sub_82A23A48) {
  static std::atomic<int> n{0};
  int32_t result = static_cast<int32_t>(ctx.r3.u32);
  if (result != 0 && budget(n))
    REXAPU_WARN("FMODDIAG FMOD error {} in '{}' ({}:{})", result, ansi(base, ctx.r4.u32),
                ansi(base, ctx.r6.u32), ctx.r7.u32);
  __imp__sub_82A23A48(ctx, base);
}

REX_HOOK_RAW(sub_82A2D330) {
  static std::atomic<int> n{0};
  bool on = REXCVAR_GET(fmod_diag);
  std::string name = on ? (ctx.r4.u32 ? wide(base, ctx.r3.u32) : ansi(base, ctx.r3.u32)) : "";
  __imp__sub_82A2D330(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG FMOD file open '{}' -> {}", name, static_cast<int32_t>(ctx.r3.u32));
}

REX_HOOK_RAW(sub_82A2C7F8) {
  static std::atomic<int> n{0};
  uint32_t self = ctx.r3.u32;
  __imp__sub_82A2C7F8(ctx, base);
  if (budget(n))
    REXAPU_INFO("FMODDIAG UFMODSoundBank::Serialize this={:08X} entries={}", self,
                plausible(self) ? be32(base, self + 0x50) : 0);
}

REX_HOOK_RAW(sub_82A387E0) {
  static std::atomic<int> n{0};
  if (budget(n)) REXAPU_INFO("FMODDIAG UFMODLoadingSet::LoadInternal this={:08X}", ctx.r3.u32);
  __imp__sub_82A387E0(ctx, base);
}

REX_HOOK_RAW(sub_82A386E0) {
  static std::atomic<int> n{0};
  if (budget(n)) REXAPU_INFO("FMODDIAG UFMODLoadingSet::AttemptUnloadInternal this={:08X}", ctx.r3.u32);
  __imp__sub_82A386E0(ctx, base);
}

REX_HOOK_RAW(sub_82A35530) {
  static std::atomic<int> n{0};
  if (budget(n)) REXAPU_INFO("FMODDIAG UFMODMusicSystem::execPromptCue this={:08X}", ctx.r3.u32);
  __imp__sub_82A35530(ctx, base);
}

REX_HOOK_RAW(sub_82A35E30) {
  static std::atomic<int> n{0};
  if (budget(n)) REXAPU_INFO("FMODDIAG UFMODEventComponent::execPlay this={:08X}", ctx.r3.u32);
  __imp__sub_82A35E30(ctx, base);
}

REX_HOOK_RAW(sub_8232EED8) {
  static std::atomic<int> n{0};
  if (budget(n))
    REXAPU_WARN("FMODDIAG assert/log expr='{}' file='{}' line={} fmt='{}'", ansi(base, ctx.r3.u32),
                ansi(base, ctx.r4.u32), ctx.r5.u32, wide(base, ctx.r6.u32));
  __imp__sub_8232EED8(ctx, base);
}
