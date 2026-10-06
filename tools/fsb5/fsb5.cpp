// fsb5 - host-side FMOD FSB5 reader for the El Chavo Kart sound banks.
//
// The title's guest audio mixer hands the emulator silence, so this tool reads
// the cooked *.fsbcache banks (FMOD FSB5, XMA codec) directly from the user's
// dump and emits standard WAVs. XMA subsounds are wrapped in an XMA2 WAVE that
// FFmpeg decodes natively (ffmpeg -i out.wav pcm.wav); PCM subsounds are copied
// straight through. No game content is read from or written to the repo.
//
// Format reference: vgmstream src/meta/fsb5.c and FFmpeg libavformat/fsb.c,
// libavformat/wavdec.c (wav_parse_xma2_tag) and libavcodec/wmaprodec.c
// (XMA2WAVEFORMAT / XMA2WAVEFORMATEX handling).
//
// Commands:
//   fsb5 list <bank...>
//   fsb5 extract <bank> <index> <out.wav>
//   fsb5 extract-all <bank> <outdir>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <optional>
#include <string>
#include <vector>

namespace {

namespace fs = std::filesystem;

uint32_t ReadU32(const uint8_t* p) {
  return static_cast<uint32_t>(p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24));
}

uint64_t ReadU64(const uint8_t* p) {
  return static_cast<uint64_t>(ReadU32(p)) | (static_cast<uint64_t>(ReadU32(p + 4)) << 32);
}

constexpr uint32_t kCodecPcm8 = 0x01;
constexpr uint32_t kCodecPcm16 = 0x02;
constexpr uint32_t kCodecXma = 0x0A;

const uint32_t kChannelsFromMode[4] = {1, 2, 6, 8};
const uint32_t kRateFromMode[16] = {4000, 8000, 11000, 11025, 16000, 22050, 24000,
                                    32000, 44100, 48000, 96000, 0, 0, 0, 0, 0};

struct SubSound {
  uint32_t index = 0;
  uint32_t num_samples = 0;
  uint32_t data_offset = 0;
  uint8_t channels = 0;
  uint32_t sample_rate = 0;
  int32_t loop_start = 0;
  int32_t loop_end = 0;
  bool loop = false;
  uint64_t stream_offset = 0;
  uint64_t stream_size = 0;
  std::string name;
};

struct Bank {
  fs::path path;
  uint32_t version = 0;
  uint32_t codec = 0;
  uint32_t flags = 0;
  uint32_t total_subsongs = 0;
  uint32_t sample_header_size = 0;
  uint32_t name_table_size = 0;
  uint32_t sample_data_size = 0;
  uint32_t base_header_size = 0;
  std::vector<uint8_t> bytes;
  std::vector<SubSound> subs;
};

bool LoadFile(const fs::path& path, std::vector<uint8_t>& out, std::string& err) {
  std::ifstream f(path, std::ios::binary);
  if (!f) {
    err = "cannot open " + path.string();
    return false;
  }
  f.seekg(0, std::ios::end);
  const std::streamoff size = f.tellg();
  f.seekg(0, std::ios::beg);
  if (size < 0) {
    err = "cannot size " + path.string();
    return false;
  }
  out.resize(static_cast<size_t>(size));
  if (size > 0) {
    f.read(reinterpret_cast<char*>(out.data()), size);
    if (!f) {
      err = "short read on " + path.string();
      return false;
    }
  }
  return true;
}

// Parses one variable-length subsound header starting at `offset` in the sample
// header table. Returns false on a malformed header.
bool ParseSubHeader(const Bank& bank, uint32_t offset, uint32_t* stream_header_size,
                    SubSound* sub) {
  const std::vector<uint8_t>& b = bank.bytes;
  if (static_cast<uint64_t>(offset) + 8 > b.size()) {
    return false;
  }
  const uint64_t sample_mode = ReadU64(b.data() + offset);
  uint32_t header_size = 8;

  sub->num_samples = static_cast<uint32_t>((sample_mode >> 34) & 0x3FFFFFFF);
  sub->data_offset = static_cast<uint32_t>(((sample_mode >> 7) & 0x07FFFFFF) << 5);
  sub->channels = static_cast<uint8_t>(kChannelsFromMode[(sample_mode >> 5) & 0x03]);
  sub->sample_rate = kRateFromMode[(sample_mode >> 1) & 0x0F];
  const bool has_extra = (sample_mode & 0x01) != 0;

  if (has_extra) {
    const uint32_t extra_max = bank.base_header_size + bank.sample_header_size;
    uint32_t extra_offset = offset + 8;
    while (extra_offset < extra_max) {
      if (static_cast<uint64_t>(extra_offset) + 4 > b.size()) {
        return false;
      }
      const uint32_t flag = ReadU32(b.data() + extra_offset);
      const uint32_t type = (flag >> 25) & 0x7F;
      const uint32_t size = (flag >> 1) & 0xFFFFFF;
      const bool cont = (flag & 0x01) != 0;

      if (type == 0x01 && size >= 1) {
        sub->channels = b[extra_offset + 4];
      } else if (type == 0x02 && size >= 4) {
        sub->sample_rate = ReadU32(b.data() + extra_offset + 4);
      } else if (type == 0x03 && size >= 4) {
        sub->loop_start = static_cast<int32_t>(ReadU32(b.data() + extra_offset + 4));
        if (size >= 8) {
          sub->loop_end = static_cast<int32_t>(ReadU32(b.data() + extra_offset + 8)) + 1;
        }
        sub->loop = true;
      }

      extra_offset += 4 + size;
      header_size += 4 + size;
      if (!cont) {
        break;
      }
    }
  }

  *stream_header_size = header_size;
  return true;
}

bool LoadBank(const fs::path& path, Bank& bank, std::string& err) {
  bank.path = path;
  if (!LoadFile(path, bank.bytes, err)) {
    return false;
  }
  const std::vector<uint8_t>& b = bank.bytes;
  if (b.size() < 0x40 || std::memcmp(b.data(), "FSB5", 4) != 0) {
    err = path.filename().string() + ": not an FSB5 file";
    return false;
  }

  bank.version = ReadU32(b.data() + 0x04);
  bank.total_subsongs = ReadU32(b.data() + 0x08);
  bank.sample_header_size = ReadU32(b.data() + 0x0C);
  bank.name_table_size = ReadU32(b.data() + 0x10);
  bank.sample_data_size = ReadU32(b.data() + 0x14);
  bank.codec = ReadU32(b.data() + 0x18);

  if (bank.version == 1) {
    bank.flags = ReadU32(b.data() + 0x20);
    bank.base_header_size = 0x3C;
  } else if (bank.version == 0) {
    bank.base_header_size = 0x40;
  } else {
    err = path.filename().string() + ": unsupported FSB5 version " +
          std::to_string(bank.version);
    return false;
  }

  const uint64_t expected = static_cast<uint64_t>(bank.base_header_size) +
                            bank.sample_header_size + bank.name_table_size +
                            bank.sample_data_size;
  if (expected != b.size()) {
    std::fprintf(stderr,
                 "warning: %s: header says %llu bytes but file is %llu (bad rip?)\n",
                 path.filename().string().c_str(),
                 static_cast<unsigned long long>(expected),
                 static_cast<unsigned long long>(b.size()));
  }

  const uint32_t name_table_offset = bank.base_header_size + bank.sample_header_size;
  const uint32_t data_section_offset = name_table_offset + bank.name_table_size;

  bank.subs.resize(bank.total_subsongs);
  uint32_t offset = bank.base_header_size;
  for (uint32_t i = 0; i < bank.total_subsongs; ++i) {
    SubSound& sub = bank.subs[i];
    sub.index = i;
    uint32_t header_size = 0;
    if (!ParseSubHeader(bank, offset, &header_size, &sub)) {
      err = path.filename().string() + ": malformed subsound header " + std::to_string(i);
      return false;
    }

    if (i + 1 < bank.total_subsongs) {
      uint32_t next_header_size = 0;
      SubSound next;
      if (ParseSubHeader(bank, offset + header_size, &next_header_size, &next)) {
        sub.stream_size = static_cast<uint64_t>(next.data_offset) - sub.data_offset;
      }
    } else {
      sub.stream_size = static_cast<uint64_t>(bank.sample_data_size) - sub.data_offset;
    }
    sub.stream_offset = data_section_offset + sub.data_offset;

    if (bank.name_table_size > 0) {
      const uint32_t entry = name_table_offset + 4 * i;
      if (static_cast<uint64_t>(entry) + 4 <= b.size()) {
        const uint32_t name_off = ReadU32(b.data() + entry);
        const uint32_t str_off = name_table_offset + name_off;
        if (str_off < b.size()) {
          const char* s = reinterpret_cast<const char*>(b.data() + str_off);
          size_t max_len = b.size() - str_off;
          size_t len = ::strnlen(s, max_len);
          sub.name.assign(s, len);
        }
      }
    }

    offset += header_size;
  }

  return true;
}

void AppendLE(std::vector<uint8_t>& out, uint32_t v) {
  out.push_back(static_cast<uint8_t>(v & 0xFF));
  out.push_back(static_cast<uint8_t>((v >> 8) & 0xFF));
  out.push_back(static_cast<uint8_t>((v >> 16) & 0xFF));
  out.push_back(static_cast<uint8_t>((v >> 24) & 0xFF));
}

void AppendTag(std::vector<uint8_t>& out, const char* tag) {
  out.insert(out.end(), tag, tag + 4);
}

// Wraps the raw XMA frames of one subsound in a RIFF WAVE carrying an "XMA2"
// chunk (XMA2WAVEFORMAT v4). FFmpeg's WAV demuxer turns the chunk into decoder
// extradata and decodes the 2048-byte XMA frames.
void BuildXma2Wav(const Bank& bank, const SubSound& sub, std::vector<uint8_t>& out) {
  const uint8_t channels = sub.channels;
  const uint32_t num_streams = (channels + 1) / 2;

  std::vector<uint8_t> xma2(32 + 8 + 4 * num_streams, 0);
  xma2[0] = 4;  // XMA2WAVEFORMAT version 4
  xma2[1] = static_cast<uint8_t>(num_streams);
  uint8_t rate_be[4] = {static_cast<uint8_t>(sub.sample_rate >> 24),
                        static_cast<uint8_t>(sub.sample_rate >> 16),
                        static_cast<uint8_t>(sub.sample_rate >> 8),
                        static_cast<uint8_t>(sub.sample_rate)};
  std::memcpy(xma2.data() + 12, rate_be, 4);
  uint8_t dur_be[4] = {static_cast<uint8_t>(sub.num_samples >> 24),
                       static_cast<uint8_t>(sub.num_samples >> 16),
                       static_cast<uint8_t>(sub.num_samples >> 8),
                       static_cast<uint8_t>(sub.num_samples)};
  std::memcpy(xma2.data() + 28, dur_be, 4);
  const uint32_t stream_cfg_offset = 32 + 8;
  for (uint32_t s = 0; s < num_streams; ++s) {
    const int remaining = static_cast<int>(channels) - 2 * static_cast<int>(s);
    xma2[stream_cfg_offset + 4 * s] = static_cast<uint8_t>(remaining >= 2 ? 2 : 1);
  }

  std::vector<uint8_t> raw(bank.bytes.begin() + sub.stream_offset,
                           bank.bytes.begin() + sub.stream_offset + sub.stream_size);
  const size_t pad = (2048 - (raw.size() % 2048)) % 2048;
  raw.insert(raw.end(), pad, 0);

  std::vector<uint8_t> chunks;
  AppendTag(chunks, "WAVE");
  AppendTag(chunks, "XMA2");
  AppendLE(chunks, static_cast<uint32_t>(xma2.size()));
  chunks.insert(chunks.end(), xma2.begin(), xma2.end());
  AppendTag(chunks, "data");
  AppendLE(chunks, static_cast<uint32_t>(raw.size()));
  chunks.insert(chunks.end(), raw.begin(), raw.end());

  out.clear();
  AppendTag(out, "RIFF");
  AppendLE(out, static_cast<uint32_t>(chunks.size()));
  out.insert(out.end(), chunks.begin(), chunks.end());
}

void BuildPcmWav(const Bank& bank, const SubSound& sub, std::vector<uint8_t>& out) {
  const bool is16 = bank.codec == kCodecPcm16;
  const uint16_t bits = is16 ? 16 : 8;
  const uint32_t block_align = sub.channels * (bits / 8);
  const uint32_t byte_rate = sub.sample_rate * block_align;

  std::vector<uint8_t> raw(bank.bytes.begin() + sub.stream_offset,
                           bank.bytes.begin() + sub.stream_offset + sub.stream_size);

  std::vector<uint8_t> chunks;
  AppendTag(chunks, "WAVE");
  AppendTag(chunks, "fmt ");
  AppendLE(chunks, 16);
  AppendLE(chunks, 1);  // WAVE_FORMAT_PCM
  chunks.push_back(sub.channels);
  chunks.push_back(0);
  AppendLE(chunks, sub.sample_rate);
  AppendLE(chunks, byte_rate);
  chunks.push_back(static_cast<uint8_t>(block_align));
  chunks.push_back(static_cast<uint8_t>(block_align >> 8));
  AppendLE(chunks, bits);
  AppendTag(chunks, "data");
  AppendLE(chunks, static_cast<uint32_t>(raw.size()));
  chunks.insert(chunks.end(), raw.begin(), raw.end());

  out.clear();
  AppendTag(out, "RIFF");
  AppendLE(out, static_cast<uint32_t>(chunks.size()));
  out.insert(out.end(), chunks.begin(), chunks.end());
}

bool WriteWav(const Bank& bank, const SubSound& sub, const fs::path& out_path,
              std::string& err) {
  std::vector<uint8_t> wav;
  if (bank.codec == kCodecXma) {
    BuildXma2Wav(bank, sub, wav);
  } else if (bank.codec == kCodecPcm8 || bank.codec == kCodecPcm16) {
    BuildPcmWav(bank, sub, wav);
  } else {
    err = "unsupported FSB5 codec 0x" + std::to_string(bank.codec);
    return false;
  }

  if (out_path.has_parent_path()) {
    std::error_code ec;
    fs::create_directories(out_path.parent_path(), ec);
  }
  std::ofstream f(out_path, std::ios::binary);
  if (!f) {
    err = "cannot write " + out_path.string();
    return false;
  }
  f.write(reinterpret_cast<const char*>(wav.data()), wav.size());
  return f.good();
}

const char* CodecName(uint32_t codec) {
  switch (codec) {
    case kCodecPcm8: return "pcm8";
    case kCodecPcm16: return "pcm16";
    case kCodecXma: return "xma";
    default: return "?";
  }
}

int CmdList(const std::vector<fs::path>& banks) {
  int failures = 0;
  for (const fs::path& path : banks) {
    Bank bank;
    std::string err;
    if (!LoadBank(path, bank, err)) {
      std::fprintf(stderr, "error: %s\n", err.c_str());
      ++failures;
      continue;
    }
    std::printf("%s: codec=%s(%u) version=%u subsongs=%u\n",
                path.filename().string().c_str(), CodecName(bank.codec), bank.codec,
                bank.version, bank.total_subsongs);
    for (const SubSound& s : bank.subs) {
      std::printf("  #%-5u ch=%u rate=%u samples=%u off=0x%llx size=%llu%s%s\n",
                  s.index, s.channels, s.sample_rate, s.num_samples,
                  static_cast<unsigned long long>(s.stream_offset),
                  static_cast<unsigned long long>(s.stream_size),
                  s.loop ? " loop" : "", s.name.empty() ? "" : (" \"" + s.name + "\"").c_str());
    }
  }
  return failures == 0 ? 0 : 1;
}

int CmdExtract(const fs::path& bank_path, uint32_t index, const fs::path& out_path) {
  Bank bank;
  std::string err;
  if (!LoadBank(bank_path, bank, err)) {
    std::fprintf(stderr, "error: %s\n", err.c_str());
    return 1;
  }
  if (index >= bank.subs.size()) {
    std::fprintf(stderr, "error: index %u out of range (0..%zu)\n", index,
                 bank.subs.size() - 1);
    return 1;
  }
  if (!WriteWav(bank, bank.subs[index], out_path, err)) {
    std::fprintf(stderr, "error: %s\n", err.c_str());
    return 1;
  }
  std::printf("wrote %s (subsong %u, %u ch, %u Hz, %u samples)\n",
              out_path.string().c_str(), index, bank.subs[index].channels,
              bank.subs[index].sample_rate, bank.subs[index].num_samples);
  return 0;
}

int CmdExtractAll(const fs::path& bank_path, const fs::path& out_dir) {
  Bank bank;
  std::string err;
  if (!LoadBank(bank_path, bank, err)) {
    std::fprintf(stderr, "error: %s\n", err.c_str());
    return 1;
  }
  std::error_code ec;
  fs::create_directories(out_dir, ec);
  int failures = 0;
  for (const SubSound& s : bank.subs) {
    char name[32];
    std::snprintf(name, sizeof(name), "%04u.wav", s.index);
    if (!WriteWav(bank, s, out_dir / name, err)) {
      std::fprintf(stderr, "  subsong %u: %s\n", s.index, err.c_str());
      ++failures;
    }
  }
  std::printf("extracted %zu subsongs to %s (%d failures)\n", bank.subs.size(),
              out_dir.string().c_str(), failures);
  return failures == 0 ? 0 : 1;
}

void Usage() {
  std::fprintf(stderr,
               "usage:\n"
               "  fsb5 list <bank...>\n"
               "  fsb5 extract <bank> <index> <out.wav>\n"
               "  fsb5 extract-all <bank> <outdir>\n");
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2) {
    Usage();
    return 2;
  }
  const std::string cmd = argv[1];
  if (cmd == "list" && argc >= 3) {
    std::vector<fs::path> banks;
    for (int i = 2; i < argc; ++i) {
      banks.emplace_back(argv[i]);
    }
    return CmdList(banks);
  }
  if (cmd == "extract" && argc == 5) {
    return CmdExtract(argv[2], static_cast<uint32_t>(std::stoul(argv[3])), argv[4]);
  }
  if (cmd == "extract-all" && argc == 4) {
    return CmdExtractAll(argv[2], argv[3]);
  }
  Usage();
  return 2;
}
