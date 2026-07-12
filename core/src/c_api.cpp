#include "session.hpp"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>

namespace fs = std::filesystem;

namespace {

void copy_cstr(char* dest, size_t dest_len, const std::string& src) {
  if (dest_len == 0) return;
  std::snprintf(dest, dest_len, "%s", src.c_str());
}

std::string make_stub_hash(const std::string& seed) {
  // Deterministic fake hash for stub builds (not cryptographic).
  uint64_t h = 1469598103934665603ull;
  for (unsigned char c : seed) {
    h ^= c;
    h *= 1099511628211ull;
  }
  char buf[41];
  std::snprintf(buf, sizeof(buf), "%016llx%016llx",
                static_cast<unsigned long long>(h),
                static_cast<unsigned long long>(h ^ 0x9e3779b97f4a7c15ull));
  return std::string(buf).substr(0, 40);
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
std::string hash_like(const lt::torrent_handle& h) {
  auto st = h.status();
  if (st.info_hashes.has_v1()) return lt::aux::to_hex(st.info_hashes.v1);
  if (st.info_hashes.has_v2()) return lt::aux::to_hex(st.info_hashes.v2);
  return {};
}
#endif

} // namespace

extern "C" {

ot_error ot_session_apply_settings(ot_session* session, const ot_session_settings* settings) {
  if (!session || !settings) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  session->settings = *settings;
  session->apply_lt_settings();
  return OT_OK;
}

ot_error ot_session_get_settings(ot_session* session, ot_session_settings* out_settings) {
  if (!session || !out_settings) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  *out_settings = session->settings;
  return OT_OK;
}

ot_error ot_session_load_resume_dir(ot_session* session, const char* resume_dir) {
  if (!session || !resume_dir) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  session->resume_dir = resume_dir;
  std::error_code ec;
  if (!fs::exists(resume_dir, ec)) {
    fs::create_directories(resume_dir, ec);
    return OT_OK;
  }

#if OPENTORRENT_HAS_LIBTORRENT
  for (auto& entry : fs::directory_iterator(resume_dir, ec)) {
    if (!entry.is_regular_file()) continue;
    auto path = entry.path();
    if (path.extension() != ".resume") continue;
    std::ifstream in(path, std::ios::binary);
    if (!in) continue;
    std::string buf((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    try {
      lt::error_code lec;
      lt::add_torrent_params atp = lt::read_resume_data(buf, lec);
      if (lec) continue;
      if (atp.save_path.empty()) atp.save_path = session->settings.save_path;
      lt::torrent_handle h = session->lt_session->add_torrent(std::move(atp));
      TorrentRecord rec;
      rec.handle = h;
      rec.info_hash = hash_like(h);
      rec.save_path = h.status().save_path;
      rec.name = h.status().name;
      session->sync_status(rec);
      session->torrents[rec.info_hash] = rec;
      session->order.push_back(rec.info_hash);
      session->push_alert(OT_ALERT_TORRENT_ADDED, rec.info_hash, "loaded resume");
    } catch (...) {
      session->set_error("failed to load resume file: " + path.string());
    }
  }
#else
  (void)ec;
#endif
  return OT_OK;
}

ot_error ot_session_save_resume(ot_session* session) {
  if (!session) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  if (session->resume_dir.empty()) return OT_ERR_INVALID_ARG;
  std::error_code ec;
  fs::create_directories(session->resume_dir, ec);

#if OPENTORRENT_HAS_LIBTORRENT
  for (auto& kv : session->torrents) {
    auto& rec = kv.second;
    if (!rec.handle.is_valid()) continue;
    rec.handle.save_resume_data(lt::torrent_handle::save_info_dict);
  }
  // Alerts deliver write_resume_data_alert; also write lightweight markers for stub safety.
#else
  for (auto& kv : session->torrents) {
    auto path = fs::path(session->resume_dir) / (kv.first + ".resume.json");
    std::ofstream out(path);
    if (!out) continue;
    out << "{\"info_hash\":\"" << kv.first << "\",\"name\":\"" << kv.second.name
        << "\",\"save_path\":\"" << kv.second.save_path << "\"}\n";
  }
#endif
  session->push_alert(OT_ALERT_RESUME_DATA, "", "resume save requested");
  return OT_OK;
}

ot_error ot_add_magnet(ot_session* session, const char* uri, const char* save_path,
                       char* out_info_hash, size_t out_len) {
  if (!session || !uri || !out_info_hash || out_len == 0) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  std::string path = save_path && save_path[0] ? save_path : session->settings.save_path;

#if OPENTORRENT_HAS_LIBTORRENT
  lt::error_code ec;
  lt::add_torrent_params atp = lt::parse_magnet_uri(uri, ec);
  if (ec) {
    session->set_error(ec.message());
    return OT_ERR_PARSE;
  }
  atp.save_path = path;
  if (session->settings.sequential_download_default) {
    atp.flags |= lt::torrent_flags::sequential_download;
  }
  try {
    lt::torrent_handle h = session->lt_session->add_torrent(std::move(atp));
    TorrentRecord rec;
    rec.handle = h;
    rec.info_hash = hash_like(h);
    if (rec.info_hash.empty()) rec.info_hash = make_stub_hash(uri);
    rec.save_path = path;
    rec.name = h.status().name.empty() ? "Fetching metadata…" : h.status().name;
    rec.state = OT_STATE_DOWNLOADING_METADATA;
    rec.sequential = session->settings.sequential_download_default;
    session->sync_status(rec);
    session->torrents[rec.info_hash] = rec;
    session->order.push_back(rec.info_hash);
    copy_cstr(out_info_hash, out_len, rec.info_hash);
    session->push_alert(OT_ALERT_TORRENT_ADDED, rec.info_hash, "magnet added");
    return OT_OK;
  } catch (const std::exception& ex) {
    session->set_error(ex.what());
    return OT_ERR_INTERNAL;
  }
#else
  TorrentRecord rec;
  rec.info_hash = make_stub_hash(uri);
  auto existing = session->find(rec.info_hash);
  if (existing) {
    copy_cstr(out_info_hash, out_len, rec.info_hash);
    return OT_OK;
  }
  rec.name = std::string(uri).substr(0, 64);
  rec.save_path = path;
  rec.state = OT_STATE_DOWNLOADING;
  rec.progress = 0.05;
  rec.total_wanted = 100 * 1024 * 1024;
  rec.total_wanted_done = static_cast<int64_t>(rec.total_wanted * rec.progress);
  rec.download_rate = 256 * 1024;
  rec.num_peers = 3;
  rec.num_seeds = 1;
  rec.sequential = session->settings.sequential_download_default;
  ot_file_entry fe{};
  copy_cstr(fe.path, sizeof(fe.path), "stub/file.bin");
  fe.size = rec.total_wanted;
  fe.priority = OT_PRIO_NORMAL;
  fe.progress = rec.progress;
  rec.files.push_back(fe);
  session->torrents[rec.info_hash] = rec;
  session->order.push_back(rec.info_hash);
  copy_cstr(out_info_hash, out_len, rec.info_hash);
  session->push_alert(OT_ALERT_TORRENT_ADDED, rec.info_hash, "magnet added (stub)");
  return OT_OK;
#endif
}

ot_error ot_add_torrent_file(ot_session* session, const char* path, const char* save_path,
                             char* out_info_hash, size_t out_len) {
  if (!session || !path || !out_info_hash || out_len == 0) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  std::string sp = save_path && save_path[0] ? save_path : session->settings.save_path;

#if OPENTORRENT_HAS_LIBTORRENT
  try {
    lt::add_torrent_params atp;
    atp.ti = std::make_shared<lt::torrent_info>(path);
    atp.save_path = sp;
    lt::torrent_handle h = session->lt_session->add_torrent(std::move(atp));
    TorrentRecord rec;
    rec.handle = h;
    rec.info_hash = hash_like(h);
    rec.save_path = sp;
    rec.name = h.status().name;
    rec.state = OT_STATE_DOWNLOADING;
    session->sync_status(rec);
    session->torrents[rec.info_hash] = rec;
    session->order.push_back(rec.info_hash);
    copy_cstr(out_info_hash, out_len, rec.info_hash);
    session->push_alert(OT_ALERT_TORRENT_ADDED, rec.info_hash, "torrent file added");
    return OT_OK;
  } catch (const std::exception& ex) {
    session->set_error(ex.what());
    return OT_ERR_PARSE;
  }
#else
  return ot_add_magnet(session, path, sp.c_str(), out_info_hash, out_len);
#endif
}

ot_error ot_add_torrent_url(ot_session* session, const char* url, const char* save_path,
                            char* out_info_hash, size_t out_len) {
  // URL download is handled at the Flutter layer; treat as magnet/path fallback.
  return ot_add_magnet(session, url, save_path, out_info_hash, out_len);
}

ot_error ot_remove_torrent(ot_session* session, const char* info_hash, int delete_files) {
  if (!session || !info_hash) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto it = session->torrents.find(info_hash);
  if (it == session->torrents.end()) return OT_ERR_NOT_FOUND;

#if OPENTORRENT_HAS_LIBTORRENT
  if (it->second.handle.is_valid()) {
    session->lt_session->remove_torrent(
        it->second.handle,
        delete_files ? lt::session_handle::delete_files : lt::remove_flags_t{});
  }
#else
  (void)delete_files;
#endif

  session->order.erase(std::remove(session->order.begin(), session->order.end(), info_hash),
                       session->order.end());
  session->torrents.erase(it);
  session->push_alert(OT_ALERT_TORRENT_REMOVED, info_hash, "removed");
  return OT_OK;
}

ot_error ot_pause_torrent(ot_session* session, const char* info_hash) {
  if (!session || !info_hash) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) rec->handle.pause();
#endif
  rec->paused = 1;
  rec->state = OT_STATE_PAUSED;
  session->push_alert(OT_ALERT_STATE_CHANGED, info_hash, "paused");
  return OT_OK;
}

ot_error ot_resume_torrent(ot_session* session, const char* info_hash) {
  if (!session || !info_hash) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) rec->handle.resume();
#endif
  rec->paused = 0;
  rec->state = OT_STATE_DOWNLOADING;
  session->push_alert(OT_ALERT_STATE_CHANGED, info_hash, "resumed");
  return OT_OK;
}

ot_error ot_set_sequential(ot_session* session, const char* info_hash, int enabled) {
  if (!session || !info_hash) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
  rec->sequential = enabled ? 1 : 0;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) {
    if (enabled) rec->handle.set_flags(lt::torrent_flags::sequential_download);
    else rec->handle.unset_flags(lt::torrent_flags::sequential_download);
  }
#endif
  return OT_OK;
}

ot_error ot_move_storage(ot_session* session, const char* info_hash, const char* new_path) {
  if (!session || !info_hash || !new_path) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
  rec->save_path = new_path;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) rec->handle.move_storage(new_path);
#endif
  return OT_OK;
}

ot_error ot_set_torrent_limits(ot_session* session, const char* info_hash, int download_rate, int upload_rate) {
  if (!session || !info_hash) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) {
    rec->handle.set_download_limit(download_rate);
    rec->handle.set_upload_limit(upload_rate);
  }
#else
  (void)download_rate;
  (void)upload_rate;
#endif
  return OT_OK;
}

ot_error ot_set_queue_position(ot_session* session, const char* info_hash, int position) {
  if (!session || !info_hash) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
  rec->queue_position = position;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) {
    // libtorrent queue APIs: queue_position_set available on handle in recent versions
    while (rec->handle.queue_position() > position) rec->handle.queue_position_up();
    while (rec->handle.queue_position() < position) rec->handle.queue_position_down();
  }
#endif
  return OT_OK;
}

int ot_torrent_count(ot_session* session) {
  if (!session) return 0;
  std::lock_guard<std::mutex> lock(session->mutex);
  return static_cast<int>(session->order.size());
}

ot_error ot_torrent_status_at(ot_session* session, int index, ot_torrent_status* out_status) {
  if (!session || !out_status || index < 0) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  if (index >= static_cast<int>(session->order.size())) return OT_ERR_NOT_FOUND;
  auto* rec = session->find(session->order[static_cast<size_t>(index)]);
  if (!rec) return OT_ERR_NOT_FOUND;
  session->sync_status(*rec);
  *out_status = to_status(*rec);
  return OT_OK;
}

ot_error ot_torrent_status_by_hash(ot_session* session, const char* info_hash, ot_torrent_status* out_status) {
  if (!session || !info_hash || !out_status) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
  session->sync_status(*rec);
  *out_status = to_status(*rec);
  return OT_OK;
}

int ot_file_count(ot_session* session, const char* info_hash) {
  if (!session || !info_hash) return 0;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return 0;
  session->sync_status(*rec);
  return static_cast<int>(rec->files.size());
}

ot_error ot_file_at(ot_session* session, const char* info_hash, int index, ot_file_entry* out_file) {
  if (!session || !info_hash || !out_file || index < 0) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
  session->sync_status(*rec);
  if (index >= static_cast<int>(rec->files.size())) return OT_ERR_NOT_FOUND;
  *out_file = rec->files[static_cast<size_t>(index)];
  return OT_OK;
}

ot_error ot_set_file_priority(ot_session* session, const char* info_hash, int index, ot_file_priority priority) {
  if (!session || !info_hash || index < 0) return OT_ERR_INVALID_ARG;
  std::lock_guard<std::mutex> lock(session->mutex);
  auto* rec = session->find(info_hash);
  if (!rec) return OT_ERR_NOT_FOUND;
  if (index >= static_cast<int>(rec->files.size())) return OT_ERR_NOT_FOUND;
  rec->files[static_cast<size_t>(index)].priority = priority;
#if OPENTORRENT_HAS_LIBTORRENT
  if (rec->handle.is_valid()) {
    rec->handle.file_priority(lt::file_index_t{index}, static_cast<lt::download_priority_t>(priority));
  }
#endif
  return OT_OK;
}

int ot_poll_alerts(ot_session* session, ot_alert* out_alerts, int max_alerts) {
  if (!session || !out_alerts || max_alerts <= 0) return 0;
  std::lock_guard<std::mutex> lock(session->mutex);

#if OPENTORRENT_HAS_LIBTORRENT
  if (session->lt_session) {
    std::vector<lt::alert*> lt_alerts;
    session->lt_session->pop_alerts(&lt_alerts);
    for (lt::alert* a : lt_alerts) {
      if (auto* ta = lt::alert_cast<lt::state_changed_alert>(a)) {
        auto hash = hash_like(ta->handle);
        if (auto* rec = session->find(hash)) {
          session->sync_status(*rec);
          session->push_alert(OT_ALERT_STATE_CHANGED, hash, a->message());
        }
      } else if (auto* fa = lt::alert_cast<lt::torrent_finished_alert>(a)) {
        auto hash = hash_like(fa->handle);
        session->push_alert(OT_ALERT_FINISHED, hash, a->message());
      } else if (auto* ea = lt::alert_cast<lt::torrent_error_alert>(a)) {
        auto hash = hash_like(ea->handle);
        if (auto* rec = session->find(hash)) {
          rec->error = a->message();
          rec->state = OT_STATE_ERROR;
        }
        session->push_alert(OT_ALERT_ERROR, hash, a->message());
      } else if (auto* ra = lt::alert_cast<lt::save_resume_data_alert>(a)) {
        if (!session->resume_dir.empty()) {
          auto buf = lt::write_resume_data_buf(ra->params);
          auto hash = hash_like(ra->handle);
          auto path = fs::path(session->resume_dir) / (hash + ".resume");
          std::ofstream out(path, std::ios::binary);
          out.write(buf.data(), static_cast<std::streamsize>(buf.size()));
          session->push_alert(OT_ALERT_RESUME_DATA, hash, "resume written");
        }
      } else if (session->log_enabled) {
        session->push_alert(OT_ALERT_LOG, "", a->message());
      }
    }
    for (auto& kv : session->torrents) {
      session->sync_status(kv.second);
      session->push_alert(OT_ALERT_PROGRESS, kv.first, "progress");
    }
  }
#else
  // Stub: simulate slow progress for active torrents.
  for (auto& kv : session->torrents) {
    auto& rec = kv.second;
    if (rec.paused || rec.finished) continue;
    rec.progress = std::min(1.0, rec.progress + 0.01);
    rec.total_wanted_done = static_cast<int64_t>(rec.total_wanted * rec.progress);
    rec.download_rate = 128 * 1024 + static_cast<int>(rec.progress * 50 * 1024);
    if (rec.progress >= 1.0) {
      rec.finished = 1;
      rec.state = OT_STATE_SEEDING;
      session->push_alert(OT_ALERT_FINISHED, rec.info_hash, "finished (stub)");
    } else {
      session->push_alert(OT_ALERT_PROGRESS, rec.info_hash, "progress");
    }
  }
#endif

  int n = 0;
  while (!session->alerts.empty() && n < max_alerts) {
    out_alerts[n++] = session->alerts.front();
    session->alerts.pop_front();
  }
  return n;
}

const char* ot_version(void) {
#if OPENTORRENT_HAS_LIBTORRENT
  return "OpenTorrent/0.1.0 libtorrent";
#else
  return "OpenTorrent/0.1.0 stub";
#endif
}

const char* ot_last_error(ot_session* session) {
  if (!session) return "null session";
  return session->last_error.c_str();
}

void ot_set_log_enabled(ot_session* session, int enabled) {
  if (!session) return;
  std::lock_guard<std::mutex> lock(session->mutex);
  session->log_enabled = enabled ? 1 : 0;
}

} // extern "C"
