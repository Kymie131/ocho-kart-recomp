// Host-side music player for El Chavo Kart.
//
// The title's guest XAudio/XMA mixer hands the emulator silence (the voice list
// is never populated upstream), so this module plays the dump's own music on
// the host, independent of the guest. It reads pre-decoded WAVs (see
// tools/fsb5/play.ps1) through a dedicated SDL audio stream and picks the track
// from a small guest-memory state heuristic: the title's 320-slot XMA voice
// array (0x83C12330) is empty in the menu and populated during gameplay/effects.
//
// Everything is opt-in: `host_music` defaults to false, and if a WAV is missing
// or the audio device cannot open the module disables itself without touching
// the guest path.
//
// The WAVs must be 16-bit PCM; the loader converts any rate/channel layout to
// 48 kHz stereo s16 (the device format) with linear interpolation.

#pragma once

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <SDL3/SDL.h>

#include <rex/cvar.h>
#include <rex/logging.h>

REXCVAR_DEFINE_BOOL(host_music, false, "Audio",
                    "Play host-side FSB music (bypasses the silent guest mixer)");
REXCVAR_DEFINE_STRING(host_music_dir, "", "Audio",
                      "Folder with the host music WAVs (default: <game_data_root>/host_music)");
REXCVAR_DEFINE_STRING(host_music_menu, "menu.wav", "Audio",
                      "WAV played when the guest voice list is empty (menu)");
REXCVAR_DEFINE_STRING(host_music_race, "race.wav", "Audio",
                      "WAV played when the guest voice list is active (gameplay)");
REXCVAR_DEFINE_DOUBLE(host_music_gain, 0.8, "Audio", "Host music gain (0..1+)");
REXCVAR_DEFINE_INT64(host_music_state_addr, 0x83C12330, "Audio",
                     "Guest address of the XMA voice-pointer array used for state");
REXCVAR_DEFINE_INT32(host_music_state_stride, 4, "Audio",
                     "Stride between voice-pointer entries");
REXCVAR_DEFINE_INT32(host_music_state_count, 320, "Audio", "Voice-pointer entry count");
REXCVAR_DEFINE_INT32(host_music_poll_ms, 250, "Audio", "State poll interval in milliseconds");
REXCVAR_DEFINE_INT32(host_music_start_delay_ms, 15000, "Audio",
                     "Wait this long after launch before starting host music "
                     "(skips the intro/cinematics so it does not overlap)");

namespace ocho::audio {

namespace fs = std::filesystem;

// One track already converted to the device format (48 kHz stereo s16).
struct HostTrack {
  std::vector<uint8_t> pcm;
};

class HostMusic {
 public:
  using GuestReader = std::function<const uint8_t*(uint32_t guest_addr)>;

  HostMusic() = default;
  ~HostMusic() { Shutdown(); }

  HostMusic(const HostMusic&) = delete;
  HostMusic& operator=(const HostMusic&) = delete;

  bool Start(const fs::path& dir, GuestReader read_guest, uint32_t state_addr,
             uint32_t state_stride, uint32_t state_count, std::string menu_file,
             std::string race_file, float gain, int poll_ms, int start_delay_ms) {
    if (running_.load(std::memory_order_relaxed)) {
      return true;
    }
    dir_ = dir;
    read_guest_ = std::move(read_guest);
    state_addr_ = state_addr;
    state_stride_ = state_stride ? state_stride : 4;
    state_count_ = state_count ? state_count : 320;
    menu_path_ = dir_ / menu_file;
    race_path_ = dir_ / race_file;
    poll_ms_ = poll_ms > 0 ? poll_ms : 250;
    start_delay_ms_ = start_delay_ms > 0 ? start_delay_ms : 0;

    // The window backend initializes SDL's video subsystem; audio may not be up
    // yet (the runtime brings its own endpoint up later), so request it here.
    if (!SDL_InitSubSystem(SDL_INIT_AUDIO)) {
      REXLOG_WARN("host_music: SDL audio subsystem unavailable: {}", SDL_GetError());
      return false;
    }

    SDL_AudioSpec spec{};
    spec.format = SDL_AUDIO_S16;
    spec.channels = 2;
    spec.freq = 48000;
    stream_ = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec,
                                        &HostMusic::GetCallback, this);
    if (!stream_) {
      REXLOG_WARN("host_music: cannot open audio device: {}", SDL_GetError());
      return false;
    }
    SDL_SetAudioStreamGain(stream_, gain);
    SDL_ResumeAudioStreamDevice(stream_);
    silence_.assign(static_cast<size_t>(spec.freq) * 4 * 2, 0);

    running_.store(true, std::memory_order_relaxed);
    thread_ = std::thread([this] { PollLoop(); });
    REXLOG_INFO("host_music: started dir='{}' menu='{}' race='{}'", dir_.string(),
                menu_file, race_file);
    return true;
  }

  void Shutdown() {
    if (!running_.exchange(false)) {
      return;
    }
    if (thread_.joinable()) {
      thread_.join();
    }
    if (stream_) {
      SDL_DestroyAudioStream(stream_);
      stream_ = nullptr;
    }
    std::lock_guard<std::mutex> lock(track_mutex_);
    current_.reset();
  }

 private:
  static void SDLCALL GetCallback(void* user, SDL_AudioStream* stream,
                                  int additional_amount, int total_amount) {
    (void)total_amount;
    auto* self = static_cast<HostMusic*>(user);
    if (additional_amount <= 0) {
      return;
    }
    std::shared_ptr<const HostTrack> track;
    {
      std::lock_guard<std::mutex> lock(self->track_mutex_);
      track = self->current_;
    }
    if (!track || track->pcm.empty()) {
      int left = additional_amount;
      const int silence_bytes = static_cast<int>(self->silence_.size());
      while (left > 0) {
        const int chunk = std::min(left, silence_bytes);
        SDL_PutAudioStreamData(stream, self->silence_.data(), chunk);
        left -= chunk;
      }
      return;
    }

    const size_t size = track->pcm.size();
    int left = additional_amount;
    while (left > 0) {
      const size_t available = size - self->play_pos_;
      const int chunk = static_cast<int>(std::min<size_t>(static_cast<size_t>(left), available));
      SDL_PutAudioStreamData(stream, track->pcm.data() + self->play_pos_, chunk);
      self->play_pos_ += static_cast<size_t>(chunk);
      if (self->play_pos_ >= size) {
        self->play_pos_ = 0;  // loop
      }
      left -= chunk;
    }
  }

  uint32_t ReadActiveVoices() const {
    if (!read_guest_) {
      return 0;
    }
    const uint8_t* base = read_guest_(state_addr_);
    if (!base) {
      return 0;
    }
    uint32_t active = 0;
    for (uint32_t i = 0; i < state_count_; ++i) {
      const uint8_t* p = base + static_cast<size_t>(i) * state_stride_;
      // Guest memory is big-endian; a null pointer is all-zero either way.
      if (p[0] | p[1] | p[2] | p[3]) {
        ++active;
      }
    }
    return active;
  }

  void PollLoop() {
    // Skip the intro/cinematics: the title plays its own audio there and host
    // music would overlap it. Wait start_delay_ms before the first track.
    for (int slept = 0; slept < start_delay_ms_ && running_.load(std::memory_order_relaxed);
         slept += 100) {
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    if (!running_.load(std::memory_order_relaxed)) {
      return;
    }

    bool loaded = false;
    bool want_race = false;
    while (running_.load(std::memory_order_relaxed)) {
      for (int slept = 0; slept < poll_ms_ && running_.load(std::memory_order_relaxed);
           slept += 50) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
      }
      if (!running_.load(std::memory_order_relaxed)) {
        break;
      }

      const bool is_race = ReadActiveVoices() > 0;
      if (loaded && is_race == want_race) {
        continue;
      }
      want_race = is_race;
      const fs::path& path = is_race ? race_path_ : menu_path_;

      auto track = std::make_shared<HostTrack>();
      if (!LoadWav48kStereo(path, track->pcm)) {
        if (!loaded) {
          REXLOG_WARN("host_music: no usable track at '{}'", path.string());
        }
        continue;
      }
      {
        std::lock_guard<std::mutex> lock(track_mutex_);
        current_ = std::move(track);
        play_pos_ = 0;
      }
      loaded = true;
      REXLOG_INFO("host_music: playing '{}' ({})", path.filename().string(),
                  is_race ? "gameplay" : "menu");
    }
  }

  // Converts a 16-bit PCM WAV (any rate, 1/2 channels) to 48 kHz stereo s16.
  static bool LoadWav48kStereo(const fs::path& path, std::vector<uint8_t>& out) {
    std::ifstream f(path, std::ios::binary);
    if (!f) {
      return false;
    }
    std::vector<uint8_t> raw((std::istreambuf_iterator<char>(f)),
                             std::istreambuf_iterator<char>());
    if (raw.size() < 44 || std::memcmp(raw.data(), "RIFF", 4) != 0 ||
        std::memcmp(raw.data() + 8, "WAVE", 4) != 0) {
      return false;
    }

    uint16_t format = 0, channels = 0, bits = 0;
    uint32_t sample_rate = 0;
    const uint8_t* data = nullptr;
    size_t data_size = 0;

    size_t pos = 12;
    while (pos + 8 <= raw.size()) {
      const char* id = reinterpret_cast<const char*>(raw.data() + pos);
      uint32_t chunk_size = 0;
      std::memcpy(&chunk_size, raw.data() + pos + 4, 4);
      const size_t body = pos + 8;
      if (std::memcmp(id, "fmt ", 4) == 0 && body + 16 <= raw.size()) {
        std::memcpy(&format, raw.data() + body + 0, 2);
        std::memcpy(&channels, raw.data() + body + 2, 2);
        std::memcpy(&sample_rate, raw.data() + body + 4, 4);
        std::memcpy(&bits, raw.data() + body + 14, 2);
      } else if (std::memcmp(id, "data", 4) == 0) {
        data = raw.data() + body;
        data_size = std::min<size_t>(chunk_size, raw.size() - body);
        break;
      }
      pos = body + chunk_size + (chunk_size & 1);
    }

    if (!data || format != 1 || bits != 16 || channels == 0 || sample_rate == 0) {
      return false;
    }

    const size_t frame_bytes = static_cast<size_t>(channels) * 2;
    const size_t in_frames = data_size / frame_bytes;
    if (in_frames == 0) {
      return false;
    }
    auto sample_at = [&](size_t frame, size_t ch) -> float {
      const uint8_t* p = data + frame * frame_bytes + (ch < channels ? ch : 0) * 2;
      int16_t s = 0;
      std::memcpy(&s, p, 2);
      return static_cast<float>(s) / 32768.0f;
    };

    const double ratio = static_cast<double>(sample_rate) / 48000.0;
    const size_t out_frames = static_cast<size_t>(in_frames / ratio);
    out.resize(out_frames * 4);  // 2 ch * s16
    for (size_t i = 0; i < out_frames; ++i) {
      const double src = i * ratio;
      const size_t i0 = static_cast<size_t>(src);
      const size_t i1 = std::min(i0 + 1, in_frames - 1);
      const float frac = static_cast<float>(src - static_cast<double>(i0));
      for (size_t ch = 0; ch < 2; ++ch) {
        float v = sample_at(i0, ch);
        if (i1 != i0) {
          v += (sample_at(i1, ch) - v) * frac;
        }
        v = std::clamp(v, -1.0f, 1.0f);
        const int16_t s = static_cast<int16_t>(v * 32767.0f);
        std::memcpy(out.data() + (i * 2 + ch) * 2, &s, 2);
      }
    }
    return true;
  }

  fs::path dir_;
  fs::path menu_path_;
  fs::path race_path_;
  GuestReader read_guest_;
  uint32_t state_addr_ = 0x83C12330;
  uint32_t state_stride_ = 4;
  uint32_t state_count_ = 320;
  int poll_ms_ = 250;
  int start_delay_ms_ = 0;

  SDL_AudioStream* stream_ = nullptr;
  std::vector<uint8_t> silence_;

  std::atomic<bool> running_{false};
  std::thread thread_;

  std::mutex track_mutex_;
  std::shared_ptr<const HostTrack> current_;
  size_t play_pos_ = 0;  // touched only by the audio callback
};

}  // namespace ocho::audio
