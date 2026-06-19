// ESP32 CAM Car - desktop keyboard control, 2-motor steering, full-speed motion
#include "esp_camera.h"
#include <WiFi.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

#define CAMERA_MODEL_AI_THINKER

// WiFi credentials
const char *ssid = "####iM";
const char *password = "123123321";

// AI Thinker camera pins
#if defined(CAMERA_MODEL_AI_THINKER)
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22
#else
#error "Camera model not selected"
#endif

// Motor driver pins
// IN1/IN2 = forward/backward motor
// IN3/IN4 = steering motor (wheel angle left/right)
const int DRIVE_IN1 = 14;
const int DRIVE_IN2 = 2;
const int STEER_IN3 = 15;
const int STEER_IN4 = 13;
const int LIGHT_PIN = 4;

// Direction mapping
// Forward/backward were reversed in the previous build, so this version flips them.
const uint8_t DRIVE_FORWARD_IN1 = LOW;
const uint8_t DRIVE_FORWARD_IN2 = HIGH;
const uint8_t DRIVE_BACKWARD_IN1 = HIGH;
const uint8_t DRIVE_BACKWARD_IN2 = LOW;

const uint8_t STEER_LEFT_IN3 = HIGH;
const uint8_t STEER_LEFT_IN4 = LOW;
const uint8_t STEER_RIGHT_IN3 = LOW;
const uint8_t STEER_RIGHT_IN4 = HIGH;

String WiFiAddr = "";

void startCameraServer();

void MotorStopAll();
void MotorDriveForward();
void MotorDriveBackward();
void MotorDriveStop();
void MotorSteerLeft();
void MotorSteerRight();
void MotorSteerStop();
void LightSet(bool on);

static inline void writeDrive(uint8_t in1, uint8_t in2) {
  digitalWrite(DRIVE_IN1, in1);
  digitalWrite(DRIVE_IN2, in2);
}

static inline void writeSteer(uint8_t in3, uint8_t in4) {
  digitalWrite(STEER_IN3, in3);
  digitalWrite(STEER_IN4, in4);
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  Serial.setDebugOutput(false);
  Serial.println();

  pinMode(DRIVE_IN1, OUTPUT);
  pinMode(DRIVE_IN2, OUTPUT);
  pinMode(STEER_IN3, OUTPUT);
  pinMode(STEER_IN4, OUTPUT);
  pinMode(LIGHT_PIN, OUTPUT);

  MotorStopAll();
  LightSet(false);

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA;
    config.jpeg_quality = 10;
    config.fb_count = 2;
    config.fb_location = CAMERA_FB_IN_PSRAM;
#if defined(CAMERA_GRAB_LATEST)
    config.grab_mode = CAMERA_GRAB_LATEST;
#endif
  } else {
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
#if defined(CAMERA_FB_IN_DRAM)
    config.fb_location = CAMERA_FB_IN_DRAM;
#endif
#if defined(CAMERA_GRAB_LATEST)
    config.grab_mode = CAMERA_GRAB_LATEST;
#endif
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    while (true) {
      delay(1000);
    }
  }

  sensor_t *s = esp_camera_sensor_get();
  s->set_framesize(s, psramFound() ? FRAMESIZE_VGA : FRAMESIZE_QVGA);

  // Fix the upside-down image orientation.
  // If your module is mounted differently, flip these two lines.
  s->set_hmirror(s, 1);
  s->set_vflip(s, 1);

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(ssid, password);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial.print(".");
  }
  Serial.println();

  WiFiAddr = WiFi.localIP().toString();
  Serial.print("WiFi connected: ");
  Serial.println(WiFiAddr);

  startCameraServer();

  Serial.print("Open on browser: http://");
  Serial.println(WiFiAddr);
}

void loop() {
  delay(5);
}

// ---- Motor helpers ----
void MotorDriveForward() {
  writeDrive(DRIVE_FORWARD_IN1, DRIVE_FORWARD_IN2);
}

void MotorDriveBackward() {
  writeDrive(DRIVE_BACKWARD_IN1, DRIVE_BACKWARD_IN2);
}

void MotorDriveStop() {
  writeDrive(LOW, LOW);
}

void MotorSteerLeft() {
  writeSteer(STEER_LEFT_IN3, STEER_LEFT_IN4);
}

void MotorSteerRight() {
  writeSteer(STEER_RIGHT_IN3, STEER_RIGHT_IN4);
}

void MotorSteerStop() {
  writeSteer(LOW, LOW);
}

void MotorStopAll() {
  MotorDriveStop();
  MotorSteerStop();
}

void LightSet(bool on) {
  digitalWrite(LIGHT_PIN, on ? HIGH : LOW);
}
