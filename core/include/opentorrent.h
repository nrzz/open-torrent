#ifndef OPENTORRENT_H
#define OPENTORRENT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

#if defined(OPENTORRENT_STATIC)
#  define OT_API
#elif defined(_WIN32)
#  if defined(OPENTORRENT_BUILD)
#    define OT_API __declspec(dllexport)
#  else
#    define OT_API __declspec(dllimport)
#  endif
#else
#  define OT_API __attribute__((visibility("default")))
#endif

typedef struct ot_session ot_session;

typedef enum ot_error {
  OT_OK = 0,
  OT_ERR_INVALID_ARG = 1,
  OT_ERR_NOT_FOUND = 2,
  OT_ERR_ALREADY = 3,
  OT_ERR_IO = 4,
  OT_ERR_PARSE = 5,
  OT_ERR_INTERNAL = 6,
  OT_ERR_UNSUPPORTED = 7
} ot_error;

typedef enum ot_torrent_state {
  OT_STATE_UNKNOWN = 0,
  OT_STATE_CHECKING_FILES = 1,
  OT_STATE_DOWNLOADING_METADATA = 2,
  OT_STATE_DOWNLOADING = 3,
  OT_STATE_FINISHED = 4,
  OT_STATE_SEEDING = 5,
  OT_STATE_CHECKING_RESUME = 6,
  OT_STATE_PAUSED = 7,
  OT_STATE_QUEUED = 8,
  OT_STATE_ERROR = 9
} ot_torrent_state;

typedef enum ot_file_priority {
  OT_PRIO_SKIP = 0,
  OT_PRIO_LOW = 1,
  OT_PRIO_NORMAL = 4,
  OT_PRIO_HIGH = 7
} ot_file_priority;

typedef enum ot_alert_type {
  OT_ALERT_NONE = 0,
  OT_ALERT_TORRENT_ADDED = 1,
  OT_ALERT_TORRENT_REMOVED = 2,
  OT_ALERT_STATE_CHANGED = 3,
  OT_ALERT_PROGRESS = 4,
  OT_ALERT_METADATA = 5,
  OT_ALERT_FINISHED = 6,
  OT_ALERT_ERROR = 7,
  OT_ALERT_RESUME_DATA = 8,
  OT_ALERT_LOG = 9
} ot_alert_type;

typedef struct ot_session_settings {
  char save_path[1024];
  int listen_port;
  int download_rate_limit; /* bytes/sec, 0 = unlimited */
  int upload_rate_limit;
  int max_connections;
  int max_uploads;
  int enable_dht;
  int enable_lsd;
  int enable_pex;
  int encryption_mode; /* 0=disabled 1=enabled 2=forced */
  int sequential_download_default;
  char proxy_host[256];
  int proxy_port;
  char proxy_username[128];
  char proxy_password[128];
  char blocklist_path[1024];
  int wifi_only; /* hint for UI/platform layer */
} ot_session_settings;

typedef struct ot_torrent_status {
  char info_hash[64];
  char name[512];
  char save_path[1024];
  char error_message[512];
  ot_torrent_state state;
  double progress; /* 0.0 - 1.0 */
  int64_t total_wanted;
  int64_t total_wanted_done;
  int64_t total_download;
  int64_t total_upload;
  int download_rate;
  int upload_rate;
  int num_peers;
  int num_seeds;
  int queue_position;
  int sequential;
  int paused;
  int finished;
  int64_t eta_seconds; /* -1 if unknown */
} ot_torrent_status;

typedef struct ot_file_entry {
  char path[1024];
  int64_t size;
  ot_file_priority priority;
  double progress;
} ot_file_entry;

typedef struct ot_alert {
  ot_alert_type type;
  char info_hash[64];
  char message[1024];
  ot_torrent_status status;
} ot_alert;

/* Session lifecycle */
OT_API ot_session* ot_session_create(const ot_session_settings* settings);
OT_API void ot_session_destroy(ot_session* session);
OT_API ot_error ot_session_apply_settings(ot_session* session, const ot_session_settings* settings);
OT_API ot_error ot_session_get_settings(ot_session* session, ot_session_settings* out_settings);
OT_API ot_error ot_session_load_resume_dir(ot_session* session, const char* resume_dir);
OT_API ot_error ot_session_save_resume(ot_session* session);

/* Torrents */
OT_API ot_error ot_add_magnet(ot_session* session, const char* uri, const char* save_path, char* out_info_hash, size_t out_len);
OT_API ot_error ot_add_torrent_file(ot_session* session, const char* path, const char* save_path, char* out_info_hash, size_t out_len);
OT_API ot_error ot_add_torrent_url(ot_session* session, const char* url, const char* save_path, char* out_info_hash, size_t out_len);
OT_API ot_error ot_remove_torrent(ot_session* session, const char* info_hash, int delete_files);
OT_API ot_error ot_pause_torrent(ot_session* session, const char* info_hash);
OT_API ot_error ot_resume_torrent(ot_session* session, const char* info_hash);
OT_API ot_error ot_set_sequential(ot_session* session, const char* info_hash, int enabled);
OT_API ot_error ot_move_storage(ot_session* session, const char* info_hash, const char* new_path);
OT_API ot_error ot_set_torrent_limits(ot_session* session, const char* info_hash, int download_rate, int upload_rate);
OT_API ot_error ot_set_queue_position(ot_session* session, const char* info_hash, int position);

OT_API int ot_torrent_count(ot_session* session);
OT_API ot_error ot_torrent_status_at(ot_session* session, int index, ot_torrent_status* out_status);
OT_API ot_error ot_torrent_status_by_hash(ot_session* session, const char* info_hash, ot_torrent_status* out_status);

OT_API int ot_file_count(ot_session* session, const char* info_hash);
OT_API ot_error ot_file_at(ot_session* session, const char* info_hash, int index, ot_file_entry* out_file);
OT_API ot_error ot_set_file_priority(ot_session* session, const char* info_hash, int index, ot_file_priority priority);

/* Alerts — poll from a background isolate / thread */
OT_API int ot_poll_alerts(ot_session* session, ot_alert* out_alerts, int max_alerts);

/* Version / diagnostics */
OT_API const char* ot_version(void);
OT_API const char* ot_last_error(ot_session* session);
OT_API void ot_set_log_enabled(ot_session* session, int enabled);

#ifdef __cplusplus
}
#endif

#endif /* OPENTORRENT_H */
