#pragma once

#include "opentorrent.h"

#include <cstddef>
#include <string>

namespace ot {

constexpr size_t kMaxMagnetLen = 4096;
constexpr size_t kMaxPathLen = 4096;
constexpr size_t kMaxResumeFileBytes = 1024 * 1024; // 1 MiB
constexpr int kMinListenPort = 1024;
constexpr int kMaxListenPort = 65535;

bool cstr_len_ok(const char* s, size_t max_len);
bool is_hex_info_hash(const char* hash);
bool validate_listen_port(int port);
bool sanitize_settings(ot_session_settings* settings);

/** Reject paths containing ".." segments. Returns empty on failure. */
std::string sanitize_path(const char* path);

/**
 * True if candidate canonicalizes under root (or equals root).
 * Empty candidate is treated as not under root.
 */
bool path_under_root(const std::string& root, const std::string& candidate);

} // namespace ot
