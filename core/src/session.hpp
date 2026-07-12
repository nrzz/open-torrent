#pragma once

#include "opentorrent.h"

#ifndef OPENTORRENT_HAS_LIBTORRENT
#define OPENTORRENT_HAS_LIBTORRENT 0
#endif

#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#if OPENTORRENT_HAS_LIBTORRENT
#include <libtorrent/session.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/hex.hpp>
#endif

struct TorrentRecord {
  std::string info_hash;
  std::string name;
  std::string save_path;
  std::string error;
  ot_torrent_state state = OT_STATE_UNKNOWN;
  double progress = 0.0;
  int64_t total_wanted = 0;
  int64_t total_wanted_done = 0;
  int64_t total_download = 0;
  int64_t total_upload = 0;
  int download_rate = 0;
  int upload_rate = 0;
  int num_peers = 0;
  int num_seeds = 0;
  int queue_position = 0;
  int sequential = 0;
  int paused = 0;
  int finished = 0;
  int64_t eta_seconds = -1;
  std::vector<ot_file_entry> files;
#if OPENTORRENT_HAS_LIBTORRENT
  lt::torrent_handle handle;
#endif
};

struct ot_session {
  std::mutex mutex;
  ot_session_settings settings{};
  std::string last_error;
  int log_enabled = 0;
  std::deque<ot_alert> alerts;
  std::unordered_map<std::string, TorrentRecord> torrents;
  std::vector<std::string> order;
  std::string resume_dir;

#if OPENTORRENT_HAS_LIBTORRENT
  std::unique_ptr<lt::session> lt_session;
#endif

  void push_alert(ot_alert_type type, const std::string& hash, const std::string& message);
  void set_error(const std::string& msg);
  TorrentRecord* find(const std::string& hash);
  void sync_status(TorrentRecord& rec);
  void apply_lt_settings();
};
