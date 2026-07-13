#include "utils.hpp"

#include <cctype>
#include <cstring>
#include <filesystem>
#include <system_error>

namespace fs = std::filesystem;

namespace ot {

bool cstr_len_ok(const char* s, size_t max_len) {
  if (!s) return false;
  size_t n = 0;
  while (s[n] != '\0') {
    if (++n > max_len) return false;
  }
  return true;
}

bool is_hex_info_hash(const char* hash) {
  if (!hash) return false;
  const size_t len = std::strlen(hash);
  // v1 SHA-1 hex = 40; accept 32–64 hex digits for v2 truncated forms too.
  if (len < 32 || len > 64) return false;
  for (size_t i = 0; i < len; ++i) {
    const unsigned char c = static_cast<unsigned char>(hash[i]);
    if (!std::isxdigit(c)) return false;
  }
  return true;
}

bool validate_listen_port(int port) {
  return port == 0 || (port >= kMinListenPort && port <= kMaxListenPort);
}

bool sanitize_settings(ot_session_settings* settings) {
  if (!settings) return false;
  // Ensure fixed buffers are null-terminated.
  settings->save_path[sizeof(settings->save_path) - 1] = '\0';
  settings->proxy_host[sizeof(settings->proxy_host) - 1] = '\0';
  settings->proxy_username[sizeof(settings->proxy_username) - 1] = '\0';
  settings->proxy_password[sizeof(settings->proxy_password) - 1] = '\0';
  settings->blocklist_path[sizeof(settings->blocklist_path) - 1] = '\0';
  if (!validate_listen_port(settings->listen_port)) return false;
  if (settings->proxy_port < 0 || settings->proxy_port > 65535) return false;
  return true;
}

std::string sanitize_path(const char* path) {
  if (!path || !cstr_len_ok(path, kMaxPathLen)) return {};
  std::string s(path);
  // Reject obvious traversal tokens before canonicalization.
  if (s.find("..") != std::string::npos) {
    // Allow ".." only when it is not a path segment — still reject all for safety.
    return {};
  }
  return s;
}

bool path_under_root(const std::string& root, const std::string& candidate) {
  if (root.empty() || candidate.empty()) return false;
  std::error_code ec;
  fs::path root_p = fs::weakly_canonical(fs::path(root), ec);
  if (ec) root_p = fs::absolute(fs::path(root), ec);
  if (ec) return false;
  fs::path cand_p = fs::weakly_canonical(fs::path(candidate), ec);
  if (ec) cand_p = fs::absolute(fs::path(candidate), ec);
  if (ec) return false;
  auto root_s = root_p.lexically_normal().string();
  auto cand_s = cand_p.lexically_normal().string();
#if defined(_WIN32)
  for (auto& c : root_s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  for (auto& c : cand_s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
#endif
  if (cand_s == root_s) return true;
  if (root_s.back() != '/' && root_s.back() != '\\') {
#if defined(_WIN32)
    root_s.push_back('\\');
#else
    root_s.push_back('/');
#endif
  }
  return cand_s.size() >= root_s.size() && cand_s.compare(0, root_s.size(), root_s) == 0;
}

} // namespace ot
