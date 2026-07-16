#include "session.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;

namespace {

void zero_settings(ot_session_settings& s) {
  std::memset(&s, 0, sizeof(s));
  s.listen_port = 6881;
  s.max_connections = 200;
  s.max_uploads = 8;
  s.enable_dht = 1;
  s.enable_lsd = 1;
  s.enable_pex = 1;
  s.encryption_mode = 1;
}

void copy_cstr(char* dest, size_t dest_len, const std::string& src) {
  if (dest_len == 0) return;
  std::snprintf(dest, dest_len, "%s", src.c_str());
}

ot_torrent_status to_status(const TorrentRecord& rec) {
  ot_torrent_status st{};
  copy_cstr(st.info_hash, sizeof(st.info_hash), rec.info_hash);
  copy_cstr(st.name, sizeof(st.name), rec.name);
  copy_cstr(st.save_path, sizeof(st.save_path), rec.save_path);
  copy_cstr(st.error_message, sizeof(st.error_message), rec.error);
  st.state = rec.state;
  st.progress = rec.progress;
  st.total_wanted = rec.total_wanted;
  st.total_wanted_done = rec.total_wanted_done;
  st.total_download = rec.total_download;
  st.total_upload = rec.total_upload;
  st.download_rate = rec.download_rate;
  st.upload_rate = rec.upload_rate;
  st.num_peers = rec.num_peers;
  st.num_seeds = rec.num_seeds;
  st.queue_position = rec.queue_position;
  st.sequential = rec.sequential;
  st.paused = rec.paused;
  st.finished = rec.finished;
  st.eta_seconds = rec.eta_seconds;
  return st;
}

#if OPENTORRENT_HAS_LIBTORRENT
std::string to_hex_bytes(lt::span<char const> s) {
  static constexpr char kHex[] = "0123456789abcdef";
  std::string out;
  out.resize(static_cast<size_t>(s.size()) * 2);
  for (int i = 0; i < s.size(); ++i) {
    auto const b = static_cast<unsigned char>(s[i]);
    out[static_cast<size_t>(i) * 2] = kHex[b >> 4];
    out[static_cast<size_t>(i) * 2 + 1] = kHex[b & 0x0f];
  }
  return out;
}

std::string hash_to_hex(const lt::sha1_hash& h) {
  return to_hex_bytes(h);
}

std::string hash_to_hex(const lt::info_hash_t& ih) {
  if (ih.has_v1()) return to_hex_bytes(ih.v1);
  if (ih.has_v2()) return to_hex_bytes(ih.get_best());
  return {};
}

ot_torrent_state map_state(lt::torrent_status::state_t state, bool paused) {
  if (paused) return OT_STATE_PAUSED;
  switch (state) {
    case lt::torrent_status::checking_files: return OT_STATE_CHECKING_FILES;
    case lt::torrent_status::downloading_metadata: return OT_STATE_DOWNLOADING_METADATA;
    case lt::torrent_status::downloading: return OT_STATE_DOWNLOADING;
    case lt::torrent_status::finished: return OT_STATE_FINISHED;
    case lt::torrent_status::seeding: return OT_STATE_SEEDING;
    case lt::torrent_status::checking_resume_data: return OT_STATE_CHECKING_RESUME;
    default: return OT_STATE_UNKNOWN;
  }
}
#endif

} // namespace

void ot_session::push_alert(ot_alert_type type, const std::string& hash, const std::string& message) {
  ot_alert a{};
  a.type = type;
  copy_cstr(a.info_hash, sizeof(a.info_hash), hash);
  copy_cstr(a.message, sizeof(a.message), message);
  auto* rec = find(hash);
  if (rec) a.status = to_status(*rec);
  alerts.push_back(a);
  while (alerts.size() > 512) alerts.pop_front();
}

void ot_session::set_error(const std::string& msg) {
  last_error = msg;
  std::snprintf(last_error_buf, sizeof(last_error_buf), "%s", msg.c_str());
  if (log_enabled) push_alert(OT_ALERT_LOG, "", msg);
}

TorrentRecord* ot_session::find(const std::string& hash) {
  auto it = torrents.find(hash);
  if (it == torrents.end()) return nullptr;
  return &it->second;
}

void ot_session::sync_status(TorrentRecord& rec) {
#if OPENTORRENT_HAS_LIBTORRENT
  if (!rec.handle.is_valid()) return;
  lt::torrent_status st = rec.handle.status();
  rec.name = st.name;
  rec.progress = st.progress;
  rec.total_wanted = st.total_wanted;
  rec.total_wanted_done = st.total_wanted_done;
  rec.total_download = st.all_time_download;
  rec.total_upload = st.all_time_upload;
  rec.download_rate = st.download_rate;
  rec.upload_rate = st.upload_rate;
  rec.num_peers = st.num_peers;
  rec.num_seeds = st.num_seeds;
  rec.queue_position = static_cast<int>(static_cast<std::int32_t>(st.queue_position));
  const bool paused = bool(st.flags & lt::torrent_flags::paused);
  rec.paused = paused ? 1 : 0;
  rec.finished = st.is_finished ? 1 : 0;
  rec.state = map_state(st.state, paused);
  if (st.download_rate > 0 && st.total_wanted > st.total_wanted_done) {
    rec.eta_seconds = static_cast<int64_t>((st.total_wanted - st.total_wanted_done) / st.download_rate);
  } else {
    rec.eta_seconds = -1;
  }
  if (std::shared_ptr<const lt::torrent_info> ti = st.torrent_file.lock()) {
    rec.files.clear();
    auto const& fs_storage = ti->files();
    auto prio = rec.handle.get_file_priorities();
    for (lt::file_index_t i(0); i < fs_storage.end_file(); ++i) {
      ot_file_entry fe{};
      copy_cstr(fe.path, sizeof(fe.path), fs_storage.file_path(i));
      fe.size = fs_storage.file_size(i);
      const int idx = static_cast<int>(static_cast<std::int32_t>(i));
      if (idx >= 0 && idx < static_cast<int>(prio.size())) {
        fe.priority = static_cast<ot_file_priority>(
            static_cast<std::uint8_t>(prio[static_cast<std::size_t>(idx)]));
      } else {
        fe.priority = OT_PRIO_NORMAL;
      }
      fe.progress = (fe.size > 0)
          ? static_cast<double>(st.total_wanted_done) / static_cast<double>(st.total_wanted)
          : 1.0;
      rec.files.push_back(fe);
    }
  }
#else
  (void)rec;
#endif
}

void ot_session::apply_lt_settings() {
#if OPENTORRENT_HAS_LIBTORRENT
  if (!lt_session) return;
  lt::settings_pack pack;
  pack.set_int(lt::settings_pack::download_rate_limit, settings.download_rate_limit);
  pack.set_int(lt::settings_pack::upload_rate_limit, settings.upload_rate_limit);
  pack.set_int(lt::settings_pack::connections_limit, settings.max_connections);
  pack.set_int(lt::settings_pack::unchoke_slots_limit, settings.max_uploads);
  pack.set_bool(lt::settings_pack::enable_dht, settings.enable_dht != 0);
  pack.set_bool(lt::settings_pack::enable_lsd, settings.enable_lsd != 0);
  pack.set_bool(lt::settings_pack::enable_outgoing_utp, true);
  pack.set_bool(lt::settings_pack::enable_incoming_utp, true);
  if (settings.encryption_mode == 0) {
    pack.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_disabled);
    pack.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_disabled);
  } else if (settings.encryption_mode == 2) {
    pack.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_forced);
    pack.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_forced);
  } else {
    pack.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_enabled);
    pack.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_enabled);
  }
  if (settings.proxy_host[0] != '\0' && settings.proxy_port > 0) {
    pack.set_str(lt::settings_pack::proxy_hostname, settings.proxy_host);
    pack.set_int(lt::settings_pack::proxy_port, settings.proxy_port);
    pack.set_str(lt::settings_pack::proxy_username, settings.proxy_username);
    pack.set_str(lt::settings_pack::proxy_password, settings.proxy_password);
    pack.set_int(lt::settings_pack::proxy_type, lt::settings_pack::socks5_pw);
  }
  if (settings.listen_port > 0 && settings.listen_port >= 1024 && settings.listen_port <= 65535) {
    char listen[64];
    std::snprintf(listen, sizeof(listen), "0.0.0.0:%d,[::]:%d", settings.listen_port, settings.listen_port);
    pack.set_str(lt::settings_pack::listen_interfaces, listen);
  }
  // UPnP / NAT-PMP for inbound connectivity (qBittorrent-class default).
  pack.set_bool(lt::settings_pack::enable_upnp, true);
  pack.set_bool(lt::settings_pack::enable_natpmp, true);
  lt_session->apply_settings(pack);

  if (settings.blocklist_path[0] != '\0') {
    try {
      lt::ip_filter filter;
      std::ifstream in(settings.blocklist_path);
      if (in) {
        std::string line;
        while (std::getline(in, line)) {
          if (line.empty() || line[0] == '#' || line[0] == ';') continue;
          // Accept "start - end" or CIDR-less "a.b.c.d - e.f.g.h" (DAT/P2P style).
          auto dash = line.find('-');
          if (dash == std::string::npos) continue;
          auto start = line.substr(0, dash);
          auto end = line.substr(dash + 1);
          auto trim = [](std::string& s) {
            while (!s.empty() && (s.front() == ' ' || s.front() == '\t')) s.erase(s.begin());
            while (!s.empty() && (s.back() == ' ' || s.back() == '\t' || s.back() == '\r')) s.pop_back();
          };
          trim(start);
          trim(end);
          lt::error_code ec1, ec2;
          auto a = lt::make_address(start, ec1);
          auto b = lt::make_address(end, ec2);
          if (!ec1 && !ec2) {
            filter.add_rule(a, b, lt::ip_filter::blocked);
          }
        }
        lt_session->set_ip_filter(filter);
      }
    } catch (...) {
      // Invalid blocklist must not crash the session.
    }
  }
#endif
}

ot_session* ot_session_create(const ot_session_settings* settings) {
  auto* session = new ot_session();
  zero_settings(session->settings);
  if (settings) {
    session->settings = *settings;
    session->settings.save_path[sizeof(session->settings.save_path) - 1] = '\0';
    session->settings.proxy_host[sizeof(session->settings.proxy_host) - 1] = '\0';
    session->settings.proxy_username[sizeof(session->settings.proxy_username) - 1] = '\0';
    session->settings.proxy_password[sizeof(session->settings.proxy_password) - 1] = '\0';
    session->settings.blocklist_path[sizeof(session->settings.blocklist_path) - 1] = '\0';
    if (session->settings.listen_port != 0 &&
        (session->settings.listen_port < 1024 || session->settings.listen_port > 65535)) {
      session->settings.listen_port = 6881;
    }
  }
  if (session->settings.save_path[0] == '\0') {
    copy_cstr(session->settings.save_path, sizeof(session->settings.save_path), ".");
  }

#if OPENTORRENT_HAS_LIBTORRENT
  lt::settings_pack pack;
  pack.set_str(lt::settings_pack::user_agent, "OpenTorrent/0.3.1 libtorrent/" LIBTORRENT_VERSION);
  pack.set_bool(lt::settings_pack::enable_dht, true);
  pack.set_bool(lt::settings_pack::enable_lsd, true);
  pack.set_int(lt::settings_pack::alert_mask,
               lt::alert_category::error | lt::alert_category::status |
               lt::alert_category::storage | lt::alert_category::torrent_log);
  session->lt_session = std::make_unique<lt::session>(pack);
  session->apply_lt_settings();
#endif

  session->push_alert(OT_ALERT_LOG, "", "session created");
  return session;
}

void ot_session_destroy(ot_session* session) {
  if (!session) return;
  std::string resume_copy;
  {
    std::lock_guard<std::mutex> lock(session->mutex);
    if (session->destroyed) return;
    session->destroyed = true;
    resume_copy = session->resume_dir;
  }
  // Best-effort resume flush before tearing down (Dart should also call save first).
  if (!resume_copy.empty()) {
    ot_session_save_resume(session);
    ot_alert sink[64];
    for (int i = 0; i < 8; ++i) {
      if (ot_poll_alerts(session, sink, 64) == 0) break;
    }
  }
  {
    std::lock_guard<std::mutex> lock(session->mutex);
#if OPENTORRENT_HAS_LIBTORRENT
    if (session->lt_session) {
      session->lt_session->pause();
      session->lt_session.reset();
    }
#endif
  }
  delete session;
}
