// Generated from the codegen call graph: call tree under FMOD
// EventSystemI::load (0x82FAECD8), depth <= 5. Each hook logs entry args and the
// returned r3 while a load is in progress on this thread (--fmod_diag=true).
// Purpose: find the callee that hands back the bogus FMOD_RESULT seen in
// "EventSystem::load ... -> 1880663472".

#include <atomic>
#include <cstdint>

#include <rex/cvar.h>
#include <rex/hook.h>
#include <rex/logging.h>

REXCVAR_DECLARE(bool, fmod_diag);

namespace fmod_trace {
thread_local int g_depth = -1;   // -1: not inside EventSystemI::load
std::atomic<int> g_lines{0};
constexpr int kMaxLines = 4000;
inline bool on() { return g_depth >= 0 && REXCVAR_GET(fmod_diag) && g_lines.load() < kMaxLines; }
}  // namespace fmod_trace

#define FT_HOOK(name, addr)                                                                    \
  REX_EXTERN(__imp__##name);                                                                   \
  REX_HOOK_RAW(name) {                                                                         \
    if (!fmod_trace::on()) { __imp__##name(ctx, base); return; }                               \
    int d = ++fmod_trace::g_depth;                                                             \
    uint32_t a3 = ctx.r3.u32, a4 = ctx.r4.u32, a5 = ctx.r5.u32, a6 = ctx.r6.u32, sp = ctx.r1.u32; \
    __imp__##name(ctx, base);                                                                  \
    fmod_trace::g_depth = d - 1;                                                               \
    if (fmod_trace::g_lines.fetch_add(1) < fmod_trace::kMaxLines)                              \
      REXAPU_INFO("FMODTRACE {:>{}}{:08X}({:08X},{:08X},{:08X},{:08X}) sp={:08X} -> {:08X}", "", \
                  d * 2, addr, a3, a4, a5, a6, sp, ctx.r3.u32);                                \
  }

// Root: EventSystemI::load. Marks the thread as "inside load".
REX_EXTERN(__imp__sub_82FAECD8);
REX_HOOK_RAW(sub_82FAECD8) {
  bool top = fmod_trace::g_depth < 0 && REXCVAR_GET(fmod_diag);
  if (top) {
    fmod_trace::g_depth = 0;
    uint32_t data = ctx.r4.u32;
    uint8_t* p = base + data;
    REXAPU_INFO("FMODTRACE load enter this={:08X} data={:08X} info={:08X} first16={:02X}{:02X}{:02X}{:02X} {:02X}{:02X}{:02X}{:02X} {:02X}{:02X}{:02X}{:02X} {:02X}{:02X}{:02X}{:02X}",
                ctx.r3.u32, data, ctx.r5.u32, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8],
                p[9], p[10], p[11], p[12], p[13], p[14], p[15]);
  }
  __imp__sub_82FAECD8(ctx, base);
  if (top) {
    REXAPU_INFO("FMODTRACE load leave -> {:08X}", ctx.r3.u32);
    fmod_trace::g_depth = -1;
  }
}

FT_HOOK(sub_82EA85A0, 0x82EA85A0u)
FT_HOOK(sub_82EAEE28, 0x82EAEE28u)
FT_HOOK(sub_82EAEEB8, 0x82EAEEB8u)
FT_HOOK(sub_82EAF350, 0x82EAF350u)
FT_HOOK(sub_82EAF480, 0x82EAF480u)
FT_HOOK(sub_82EB8AB8, 0x82EB8AB8u)
FT_HOOK(sub_82EBFFA8, 0x82EBFFA8u)
FT_HOOK(sub_82EC0530, 0x82EC0530u)
FT_HOOK(sub_82EC06D8, 0x82EC06D8u)
FT_HOOK(sub_82EC0940, 0x82EC0940u)
FT_HOOK(sub_82EC0A90, 0x82EC0A90u)
FT_HOOK(sub_82EC1170, 0x82EC1170u)
FT_HOOK(sub_82EC1C68, 0x82EC1C68u)
FT_HOOK(sub_82EC88C0, 0x82EC88C0u)
FT_HOOK(sub_82EC9E48, 0x82EC9E48u)
FT_HOOK(sub_82ED1C98, 0x82ED1C98u)
FT_HOOK(sub_82ED20F0, 0x82ED20F0u)
FT_HOOK(sub_82ED2188, 0x82ED2188u)
FT_HOOK(sub_82ED2328, 0x82ED2328u)
FT_HOOK(sub_82ED2580, 0x82ED2580u)
FT_HOOK(sub_82ED28B8, 0x82ED28B8u)
FT_HOOK(sub_82ED2998, 0x82ED2998u)
FT_HOOK(sub_82ED2CB8, 0x82ED2CB8u)
FT_HOOK(sub_82ED3548, 0x82ED3548u)
FT_HOOK(sub_82ED3708, 0x82ED3708u)
FT_HOOK(sub_82ED3C08, 0x82ED3C08u)
FT_HOOK(sub_82ED3C38, 0x82ED3C38u)
FT_HOOK(sub_82ED45B8, 0x82ED45B8u)
FT_HOOK(sub_82ED48D8, 0x82ED48D8u)
FT_HOOK(sub_82ED4900, 0x82ED4900u)
FT_HOOK(sub_82ED49B8, 0x82ED49B8u)
FT_HOOK(sub_82ED4A20, 0x82ED4A20u)
FT_HOOK(sub_82ED4A60, 0x82ED4A60u)
FT_HOOK(sub_82ED4B08, 0x82ED4B08u)
FT_HOOK(sub_82ED4B48, 0x82ED4B48u)
FT_HOOK(sub_82ED4B90, 0x82ED4B90u)
FT_HOOK(sub_82ED9D50, 0x82ED9D50u)
FT_HOOK(sub_82ED9D78, 0x82ED9D78u)
FT_HOOK(sub_82ED9D98, 0x82ED9D98u)
FT_HOOK(sub_82ED9DC8, 0x82ED9DC8u)
FT_HOOK(sub_82ED9E08, 0x82ED9E08u)
FT_HOOK(sub_82ED9F10, 0x82ED9F10u)
FT_HOOK(sub_82ED9F90, 0x82ED9F90u)
FT_HOOK(sub_82EDA0D0, 0x82EDA0D0u)
FT_HOOK(sub_82EDA168, 0x82EDA168u)
FT_HOOK(sub_82F35158, 0x82F35158u)
FT_HOOK(sub_82F356F8, 0x82F356F8u)
FT_HOOK(sub_82F3D9B0, 0x82F3D9B0u)
FT_HOOK(sub_82F3DD68, 0x82F3DD68u)
FT_HOOK(sub_82F3E300, 0x82F3E300u)
FT_HOOK(sub_82F3E768, 0x82F3E768u)
FT_HOOK(sub_82F3EAA8, 0x82F3EAA8u)
FT_HOOK(sub_82F3F2D8, 0x82F3F2D8u)
FT_HOOK(sub_82F9B2D0, 0x82F9B2D0u)
FT_HOOK(sub_82F9B328, 0x82F9B328u)
FT_HOOK(sub_82F9B380, 0x82F9B380u)
FT_HOOK(sub_82F9BFC0, 0x82F9BFC0u)
FT_HOOK(sub_82F9C020, 0x82F9C020u)
FT_HOOK(sub_82F9F150, 0x82F9F150u)
FT_HOOK(sub_82FA1B30, 0x82FA1B30u)
FT_HOOK(sub_82FA1C80, 0x82FA1C80u)
FT_HOOK(sub_82FA1DD8, 0x82FA1DD8u)
FT_HOOK(sub_82FA38A8, 0x82FA38A8u)
FT_HOOK(sub_82FA72B0, 0x82FA72B0u)
FT_HOOK(sub_82FA7540, 0x82FA7540u)
FT_HOOK(sub_82FA8550, 0x82FA8550u)
FT_HOOK(sub_82FA8650, 0x82FA8650u)
FT_HOOK(sub_82FAA9B8, 0x82FAA9B8u)
FT_HOOK(sub_82FACF68, 0x82FACF68u)
FT_HOOK(sub_82FAE710, 0x82FAE710u)
FT_HOOK(sub_82FAE998, 0x82FAE998u)
FT_HOOK(sub_82FAF040, 0x82FAF040u)
FT_HOOK(sub_82FAF188, 0x82FAF188u)
FT_HOOK(sub_82FAF3A0, 0x82FAF3A0u)
FT_HOOK(sub_82FAF420, 0x82FAF420u)
FT_HOOK(sub_82FAF598, 0x82FAF598u)
FT_HOOK(sub_82FAF770, 0x82FAF770u)
FT_HOOK(sub_82FAF808, 0x82FAF808u)
FT_HOOK(sub_82FAFD60, 0x82FAFD60u)
FT_HOOK(sub_82FB04C0, 0x82FB04C0u)
FT_HOOK(sub_82FB0568, 0x82FB0568u)
FT_HOOK(sub_82FB0730, 0x82FB0730u)
FT_HOOK(sub_82FB1600, 0x82FB1600u)
FT_HOOK(sub_82FB1680, 0x82FB1680u)
FT_HOOK(sub_82FB1740, 0x82FB1740u)
FT_HOOK(sub_82FB18A8, 0x82FB18A8u)
FT_HOOK(sub_82FB1A30, 0x82FB1A30u)
FT_HOOK(sub_82FB2E88, 0x82FB2E88u)
FT_HOOK(sub_82FB3990, 0x82FB3990u)
FT_HOOK(sub_82FB3A18, 0x82FB3A18u)
FT_HOOK(sub_82FB3E60, 0x82FB3E60u)
FT_HOOK(sub_82FB5A00, 0x82FB5A00u)
FT_HOOK(sub_82FB5EC8, 0x82FB5EC8u)
FT_HOOK(sub_82FB5F78, 0x82FB5F78u)
FT_HOOK(sub_82FB60B0, 0x82FB60B0u)
FT_HOOK(sub_82FB6ED0, 0x82FB6ED0u)
FT_HOOK(sub_82FB7EA0, 0x82FB7EA0u)
FT_HOOK(sub_82FB9430, 0x82FB9430u)
FT_HOOK(sub_82FB9508, 0x82FB9508u)
FT_HOOK(sub_82FB9560, 0x82FB9560u)
FT_HOOK(sub_82FB9598, 0x82FB9598u)
FT_HOOK(sub_82FB95D0, 0x82FB95D0u)
FT_HOOK(sub_82FB9A50, 0x82FB9A50u)
FT_HOOK(sub_82FBA050, 0x82FBA050u)
FT_HOOK(sub_82FBA060, 0x82FBA060u)
FT_HOOK(sub_82FBA088, 0x82FBA088u)
FT_HOOK(sub_82FBA6F0, 0x82FBA6F0u)
FT_HOOK(sub_82FBA728, 0x82FBA728u)
FT_HOOK(sub_82FBA828, 0x82FBA828u)
FT_HOOK(sub_82FBCE30, 0x82FBCE30u)
FT_HOOK(sub_82FBD4C8, 0x82FBD4C8u)
FT_HOOK(sub_82FBDA10, 0x82FBDA10u)
FT_HOOK(sub_82FBDAF8, 0x82FBDAF8u)
FT_HOOK(sub_82FBE558, 0x82FBE558u)
FT_HOOK(sub_82FBF9A0, 0x82FBF9A0u)
FT_HOOK(sub_82FBFAD0, 0x82FBFAD0u)
FT_HOOK(sub_82FBFAE0, 0x82FBFAE0u)
FT_HOOK(sub_82FBFC48, 0x82FBFC48u)
FT_HOOK(sub_82FBFFA0, 0x82FBFFA0u)
FT_HOOK(sub_82FC1E08, 0x82FC1E08u)
FT_HOOK(sub_82FC1E18, 0x82FC1E18u)
FT_HOOK(sub_82FC5640, 0x82FC5640u)
FT_HOOK(sub_82FC5908, 0x82FC5908u)
FT_HOOK(sub_82FC5C00, 0x82FC5C00u)
FT_HOOK(sub_82FC6248, 0x82FC6248u)
FT_HOOK(sub_82FC6D78, 0x82FC6D78u)
FT_HOOK(sub_82FC71A0, 0x82FC71A0u)
FT_HOOK(sub_82FC73C0, 0x82FC73C0u)
FT_HOOK(sub_82FC7D78, 0x82FC7D78u)
FT_HOOK(sub_82FCAA70, 0x82FCAA70u)
FT_HOOK(sub_82FCAC20, 0x82FCAC20u)
FT_HOOK(sub_82FCAD78, 0x82FCAD78u)
FT_HOOK(sub_82FCAFF0, 0x82FCAFF0u)
FT_HOOK(sub_82FCB0B8, 0x82FCB0B8u)
FT_HOOK(sub_82FCBD28, 0x82FCBD28u)
FT_HOOK(sub_82FCCC78, 0x82FCCC78u)
FT_HOOK(sub_82FCCD78, 0x82FCCD78u)
FT_HOOK(sub_82FCD048, 0x82FCD048u)
FT_HOOK(sub_82FD85E8, 0x82FD85E8u)
FT_HOOK(sub_82FD8830, 0x82FD8830u)
FT_HOOK(sub_82FD93B8, 0x82FD93B8u)
FT_HOOK(sub_82FD9668, 0x82FD9668u)
FT_HOOK(sub_82FD96B0, 0x82FD96B0u)
FT_HOOK(sub_82FD97A8, 0x82FD97A8u)
FT_HOOK(sub_82FD99F0, 0x82FD99F0u)
FT_HOOK(sub_82FD9C58, 0x82FD9C58u)
FT_HOOK(sub_82FD9C68, 0x82FD9C68u)
FT_HOOK(sub_82FD9FD0, 0x82FD9FD0u)
FT_HOOK(sub_82FDA638, 0x82FDA638u)
FT_HOOK(sub_82FDA708, 0x82FDA708u)
FT_HOOK(sub_82FDA760, 0x82FDA760u)
FT_HOOK(sub_82FDA778, 0x82FDA778u)
FT_HOOK(sub_82FDB178, 0x82FDB178u)
FT_HOOK(sub_82FDBB18, 0x82FDBB18u)
FT_HOOK(sub_82FDE748, 0x82FDE748u)
FT_HOOK(sub_82FDEFA0, 0x82FDEFA0u)
FT_HOOK(sub_82FDEFF8, 0x82FDEFF8u)
FT_HOOK(sub_82FDF6C0, 0x82FDF6C0u)
