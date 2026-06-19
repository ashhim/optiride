// Copyright 2015-2016 Espressif Systems (Shanghai) PTE LTD
// Updated for clean desktop UI, keyboard control, 2-motor drive, and stable streaming

#include "esp_http_server.h"
#include "esp_timer.h"
#include "esp_camera.h"
#include "img_converters.h"
#include "camera_index.h"
#include "Arduino.h"

extern void MotorStopAll();
extern void MotorDriveForward();
extern void MotorDriveBackward();
extern void MotorDriveStop();
extern void MotorSteerLeft();
extern void MotorSteerRight();
extern void MotorSteerStop();
extern void LightSet(bool on);

httpd_handle_t stream_httpd = NULL;
httpd_handle_t camera_httpd = NULL;

typedef struct {
  size_t size;
  size_t index;
  size_t count;
  int sum;
  int *values;
} ra_filter_t;

typedef struct {
  httpd_req_t *req;
  size_t len;
} jpg_chunking_t;

#define PART_BOUNDARY "123456789000000000000987654321"
static const char *_STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char *_STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char *_STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static ra_filter_t ra_filter;

static ra_filter_t *ra_filter_init(ra_filter_t *filter, size_t sample_size) {
  memset(filter, 0, sizeof(ra_filter_t));
  filter->values = (int *)malloc(sample_size * sizeof(int));
  if (!filter->values) return NULL;
  memset(filter->values, 0, sample_size * sizeof(int));
  filter->size = sample_size;
  return filter;
}

static int ra_filter_run(ra_filter_t *filter, int value) {
  if (!filter->values) return value;
  filter->sum -= filter->values[filter->index];
  filter->values[filter->index] = value;
  filter->sum += filter->values[filter->index];
  filter->index = (filter->index + 1) % filter->size;
  if (filter->count < filter->size) filter->count++;
  return filter->sum / filter->count;
}

static size_t jpg_encode_stream(void *arg, size_t index, const void *data, size_t len) {
  jpg_chunking_t *j = (jpg_chunking_t *)arg;
  if (!index) j->len = 0;
  if (httpd_resp_send_chunk(j->req, (const char *)data, len) != ESP_OK) {
    return 0;
  }
  j->len += len;
  return len;
}

static esp_err_t capture_handler(httpd_req_t *req) {
  camera_fb_t *fb = NULL;
  esp_err_t res = ESP_OK;

  fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }

  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=capture.jpg");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  httpd_resp_set_hdr(req, "Pragma", "no-cache");

  if (fb->format == PIXFORMAT_JPEG) {
    res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
  } else {
    jpg_chunking_t jchunk = {req, 0};
    res = frame2jpg_cb(fb, 80, jpg_encode_stream, &jchunk) ? ESP_OK : ESP_FAIL;
    httpd_resp_send_chunk(req, NULL, 0);
  }

  esp_camera_fb_return(fb);
  return res;
}

static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t *fb = NULL;
  esp_err_t res = ESP_OK;
  size_t jpg_buf_len = 0;
  uint8_t *jpg_buf = NULL;
  char part_buf[64];

  static int64_t last_frame = 0;
  if (!last_frame) last_frame = esp_timer_get_time();

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) return res;

  httpd_resp_set_hdr(req, "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  httpd_resp_set_hdr(req, "Pragma", "no-cache");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      res = ESP_FAIL;
    } else if (fb->format != PIXFORMAT_JPEG) {
      bool jpeg_converted = frame2jpg(fb, 80, &jpg_buf, &jpg_buf_len);
      esp_camera_fb_return(fb);
      fb = NULL;
      if (!jpeg_converted) {
        res = ESP_FAIL;
      }
    } else {
      jpg_buf_len = fb->len;
      jpg_buf = fb->buf;
    }

    if (res == ESP_OK) {
      size_t hlen = snprintf(part_buf, sizeof(part_buf), _STREAM_PART, (unsigned int)jpg_buf_len);
      res = httpd_resp_send_chunk(req, part_buf, hlen);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char *)jpg_buf, jpg_buf_len);
    }
    if (res == ESP_OK) {
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }

    if (fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
      jpg_buf = NULL;
    } else if (jpg_buf) {
      free(jpg_buf);
      jpg_buf = NULL;
    }

    if (res != ESP_OK) break;

    int64_t fr_end = esp_timer_get_time();
    int64_t frame_time = (fr_end - last_frame) / 1000;
    last_frame = fr_end;
    (void)ra_filter_run(&ra_filter, (int)frame_time);
  }

  last_frame = 0;
  return res;
}

static esp_err_t index_handler(httpd_req_t *req) {
  httpd_resp_set_type(req, "text/html; charset=utf-8");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  httpd_resp_set_hdr(req, "Pragma", "no-cache");
  return httpd_resp_send(req, index_html, HTTPD_RESP_USE_STRLEN);
}

static esp_err_t ping_handler(httpd_req_t *req) {
  httpd_resp_set_type(req, "text/plain");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");
  return httpd_resp_send(req, "OK", 2);
}

// Drive
static esp_err_t forward_handler(httpd_req_t *req) {
  MotorDriveForward();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t backward_handler(httpd_req_t *req) {
  MotorDriveBackward();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t stopdrive_handler(httpd_req_t *req) {
  MotorDriveStop();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

// Steering
static esp_err_t steerleft_handler(httpd_req_t *req) {
  MotorSteerLeft();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t steerright_handler(httpd_req_t *req) {
  MotorSteerRight();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t stopsteer_handler(httpd_req_t *req) {
  MotorSteerStop();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t stopall_handler(httpd_req_t *req) {
  MotorStopAll();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

// Light
static esp_err_t lighton_handler(httpd_req_t *req) {
  LightSet(true);
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t lightoff_handler(httpd_req_t *req) {
  LightSet(false);
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t lighttoggle_handler(httpd_req_t *req) {
  static bool light_state = false;
  light_state = !light_state;
  LightSet(light_state);
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, light_state ? "1" : "0", 1);
}

// Compatibility aliases for older page/requests
static esp_err_t go_handler(httpd_req_t *req) {
  return forward_handler(req);
}

static esp_err_t back_handler(httpd_req_t *req) {
  return backward_handler(req);
}

static esp_err_t left_handler(httpd_req_t *req) {
  return steerleft_handler(req);
}

static esp_err_t right_handler(httpd_req_t *req) {
  return steerright_handler(req);
}

static esp_err_t stop_handler(httpd_req_t *req) {
  MotorStopAll();
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, "OK", 2);
}

static esp_err_t ledon_handler(httpd_req_t *req) {
  return lighton_handler(req);
}

static esp_err_t ledoff_handler(httpd_req_t *req) {
  return lightoff_handler(req);
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;
  config.ctrl_port = 32768;
  config.stack_size = 8192;
  config.max_uri_handlers = 16;
  config.lru_purge_enable = true;

  httpd_uri_t index_uri = {.uri = "/", .method = HTTP_GET, .handler = index_handler, .user_ctx = NULL};
  httpd_uri_t ping_uri = {.uri = "/ping", .method = HTTP_GET, .handler = ping_handler, .user_ctx = NULL};

  httpd_uri_t forward_uri = {.uri = "/forward", .method = HTTP_GET, .handler = forward_handler, .user_ctx = NULL};
  httpd_uri_t backward_uri = {.uri = "/backward", .method = HTTP_GET, .handler = backward_handler, .user_ctx = NULL};
  httpd_uri_t stopdrive_uri = {.uri = "/stopdrive", .method = HTTP_GET, .handler = stopdrive_handler, .user_ctx = NULL};

  httpd_uri_t steerleft_uri = {.uri = "/steerleft", .method = HTTP_GET, .handler = steerleft_handler, .user_ctx = NULL};
  httpd_uri_t steerright_uri = {.uri = "/steerright", .method = HTTP_GET, .handler = steerright_handler, .user_ctx = NULL};
  httpd_uri_t stopsteer_uri = {.uri = "/stopsteer", .method = HTTP_GET, .handler = stopsteer_handler, .user_ctx = NULL};

  httpd_uri_t stopall_uri = {.uri = "/stopall", .method = HTTP_GET, .handler = stopall_handler, .user_ctx = NULL};

  httpd_uri_t lighton_uri = {.uri = "/lighton", .method = HTTP_GET, .handler = lighton_handler, .user_ctx = NULL};
  httpd_uri_t lightoff_uri = {.uri = "/lightoff", .method = HTTP_GET, .handler = lightoff_handler, .user_ctx = NULL};
  httpd_uri_t lighttoggle_uri = {.uri = "/lighttoggle", .method = HTTP_GET, .handler = lighttoggle_handler, .user_ctx = NULL};

  httpd_uri_t capture_uri = {.uri = "/capture", .method = HTTP_GET, .handler = capture_handler, .user_ctx = NULL};
  httpd_uri_t stream_uri = {.uri = "/stream", .method = HTTP_GET, .handler = stream_handler, .user_ctx = NULL};

  // Compatibility routes
  httpd_uri_t go_uri = {.uri = "/go", .method = HTTP_GET, .handler = go_handler, .user_ctx = NULL};
  httpd_uri_t back_uri = {.uri = "/back", .method = HTTP_GET, .handler = back_handler, .user_ctx = NULL};
  httpd_uri_t left_uri = {.uri = "/left", .method = HTTP_GET, .handler = left_handler, .user_ctx = NULL};
  httpd_uri_t right_uri = {.uri = "/right", .method = HTTP_GET, .handler = right_handler, .user_ctx = NULL};
  httpd_uri_t stop_uri = {.uri = "/stop", .method = HTTP_GET, .handler = stop_handler, .user_ctx = NULL};
  httpd_uri_t ledon_uri = {.uri = "/ledon", .method = HTTP_GET, .handler = ledon_handler, .user_ctx = NULL};
  httpd_uri_t ledoff_uri = {.uri = "/ledoff", .method = HTTP_GET, .handler = ledoff_handler, .user_ctx = NULL};

  ra_filter_init(&ra_filter, 20);

  Serial.printf("Starting web server on port: '%d'\n", config.server_port);
  if (httpd_start(&camera_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(camera_httpd, &index_uri);
    httpd_register_uri_handler(camera_httpd, &ping_uri);

    httpd_register_uri_handler(camera_httpd, &forward_uri);
    httpd_register_uri_handler(camera_httpd, &backward_uri);
    httpd_register_uri_handler(camera_httpd, &stopdrive_uri);

    httpd_register_uri_handler(camera_httpd, &steerleft_uri);
    httpd_register_uri_handler(camera_httpd, &steerright_uri);
    httpd_register_uri_handler(camera_httpd, &stopsteer_uri);

    httpd_register_uri_handler(camera_httpd, &stopall_uri);

    httpd_register_uri_handler(camera_httpd, &lighton_uri);
    httpd_register_uri_handler(camera_httpd, &lightoff_uri);
    httpd_register_uri_handler(camera_httpd, &lighttoggle_uri);

    httpd_register_uri_handler(camera_httpd, &capture_uri);

    // Compatibility
    httpd_register_uri_handler(camera_httpd, &go_uri);
    httpd_register_uri_handler(camera_httpd, &back_uri);
    httpd_register_uri_handler(camera_httpd, &left_uri);
    httpd_register_uri_handler(camera_httpd, &right_uri);
    httpd_register_uri_handler(camera_httpd, &stop_uri);
    httpd_register_uri_handler(camera_httpd, &ledon_uri);
    httpd_register_uri_handler(camera_httpd, &ledoff_uri);
  }

  config.server_port = 81;
  config.ctrl_port += 1;
  Serial.printf("Starting stream server on port: '%d'\n", config.server_port);
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_uri_t stream_uri_local = {.uri = "/stream", .method = HTTP_GET, .handler = stream_handler, .user_ctx = NULL};
    httpd_register_uri_handler(stream_httpd, &stream_uri_local);
  }
}
