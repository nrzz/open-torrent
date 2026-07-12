#include "opentorrent.h"

#include <cstdio>
#include <cstring>

#define CHECK(cond, msg) do { \
  if (!(cond)) { std::fprintf(stderr, "FAIL: %s\n", msg); return 1; } \
  std::fprintf(stderr, "ok: %s\n", msg); \
} while (0)

int main() {
  std::fprintf(stderr, "start\n");
  ot_session_settings settings{};
  std::snprintf(settings.save_path, sizeof(settings.save_path), ".");
  settings.listen_port = 6881;
  settings.enable_dht = 1;
  settings.max_connections = 50;

  ot_session* session = ot_session_create(&settings);
  CHECK(session != nullptr, "create");
  CHECK(std::strstr(ot_version(), "OpenTorrent") != nullptr, "version");

  CHECK(ot_add_magnet(nullptr, "x", ".", nullptr, 0) == OT_ERR_INVALID_ARG, "null session");
  CHECK(ot_pause_torrent(session, "missing") == OT_ERR_NOT_FOUND, "pause missing");

  char hash[64] = {};
  CHECK(ot_add_magnet(session,
                      "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test",
                      ".", hash, sizeof(hash)) == OT_OK,
        "add magnet");
  CHECK(hash[0] != '\0', "hash set");
  CHECK(ot_torrent_count(session) == 1, "count");

  char hash2[64] = {};
  CHECK(ot_add_magnet(session,
                      "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=test",
                      ".", hash2, sizeof(hash2)) == OT_OK,
        "dup");
  CHECK(ot_torrent_count(session) == 1, "dup count");

  ot_torrent_status st{};
  CHECK(ot_torrent_status_by_hash(session, hash, &st) == OT_OK, "status");
  CHECK(ot_pause_torrent(session, hash) == OT_OK, "pause");
  CHECK(ot_resume_torrent(session, hash) == OT_OK, "resume");
  CHECK(ot_set_sequential(session, hash, 1) == OT_OK, "seq");

  ot_alert alerts[32];
  int n = ot_poll_alerts(session, alerts, 32);
  CHECK(n >= 0, "poll");

  CHECK(ot_remove_torrent(session, hash, 0) == OT_OK, "remove");
  CHECK(ot_torrent_count(session) == 0, "empty");

  ot_session_settings got{};
  CHECK(ot_session_get_settings(session, &got) == OT_OK, "get settings");
  got.download_rate_limit = 42;
  CHECK(ot_session_apply_settings(session, &got) == OT_OK, "apply settings");

  ot_session_destroy(session);
  std::fprintf(stderr, "ALL PASSED\n");
  return 0;
}
