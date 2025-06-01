#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>
#include <FirebaseESP8266.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// EEPROM storage for WiFi creds (store up to 32+32 bytes)
#define EEPROM_SIZE 96
#define EEPROM_SSID_ADDR 0
#define EEPROM_PASS_ADDR 32

// Firebase credentials
#define API_KEY ""
#define DATABASE_URL ""
#define USER_EMAIL ""
#define USER_PASSWORD ""

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// MAX30102 sensor
MAX30105 particleSensor;

// ECG pin (AD8232 output)
const int ecgPin = A0;

// Wi-Fi provisioning AP credentials
const char* ap_ssid = "ESP8266_Setup";
const char* ap_password = "setup123";

// HTTP server on port 80
ESP8266WebServer server(80);

String wifi_ssid = "";
String wifi_password = "";

// Forward declarations
void startAPMode();
void startStationMode();
void handleWifiSetup();
void handleResetWifi();
void saveCredentialsToEEPROM(const String& ssid, const String& pass);
bool loadCredentialsFromEEPROM(String& ssid, String& pass);

void setup() {
  Serial.begin(115200);
  delay(100);
  EEPROM.begin(EEPROM_SIZE);

  // Load Wi-Fi credentials from EEPROM
  if (!loadCredentialsFromEEPROM(wifi_ssid, wifi_password) || wifi_ssid.length() == 0) {
    Serial.println("No WiFi credentials found, starting AP mode...");
    startAPMode();
  } else {
    Serial.printf("Loaded WiFi credentials SSID: %s\n", wifi_ssid.c_str());
    WiFi.mode(WIFI_STA);
    WiFi.begin(wifi_ssid.c_str(), wifi_password.c_str());

    Serial.print("Connecting to Wi-Fi");
    unsigned long startAttemptTime = millis();

    // Try connecting for 10 seconds
    while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 10000) {
      Serial.print(".");
      delay(500);
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("Wi-Fi connected.");
      startStationMode();
    } else {
      Serial.println("Failed to connect to Wi-Fi, starting AP mode...");
      startAPMode();
    }
  }
}

void loop() {
  if (WiFi.getMode() == WIFI_AP) {
    // Handle HTTP requests in AP mode
    server.handleClient();
    return;
  }

  // Station mode: sensor reading + Firebase upload
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();
  int ecgValue = analogRead(ecgPin); // AD8232 analog ECG reading

  if (checkForBeat(irValue)) {
    static uint8_t rates[4];
    static uint8_t rateSpot = 0;
    static long lastBeat = 0;

    long delta = millis() - lastBeat;
    lastBeat = millis();

    int bpm = 60000 / delta;

    if (bpm < 255 && bpm > 30) {
      rates[rateSpot++] = bpm;
      rateSpot %= 4;

      int beatAvg = 0;
      for (int i = 0; i < 4; i++) {
        beatAvg += rates[i];
      }
      beatAvg /= 4;

      float ratio = (float)redValue / (float)irValue;
      float spo2 = 110.0 - 25.0 * ratio;
      spo2 = constrain(spo2, 70, 100);

      if (Firebase.ready()) {
        if (!Firebase.setInt(fbdo, "/patient/HeartRate", beatAvg))
          Serial.println("Failed to upload HeartRate: " + fbdo.errorReason());

        if (!Firebase.setFloat(fbdo, "/patient/SPO2", spo2))
          Serial.println("Failed to upload SPO2: " + fbdo.errorReason());

        if (!Firebase.setInt(fbdo, "/patient/ECG", ecgValue))
          Serial.println("Failed to upload ECG: " + fbdo.errorReason());
      } else {
        Serial.println("Firebase not ready");
      }

      Serial.printf("Heart Rate: %d BPM\tSpO2: %.2f %%\tECG: %d\n", beatAvg, spo2, ecgValue);
    }
  }

  delay(10);
}

void startAPMode() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_ssid, ap_password);

  Serial.println("Started AP mode.");
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP());

  // Setup HTTP handler for Wi-Fi provisioning
  server.on("/wifi-setup", HTTP_POST, handleWifiSetup);

  // Endpoint to reset Wi-Fi credentials
  server.on("/reset-wifi", HTTP_GET, handleResetWifi);

  // Simple root page
  server.on("/", HTTP_GET, []() {
    String page = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>ESP8266 Wi-Fi Setup</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #f2f2f2;
      padding: 30px;
      text-align: center;
    }
    .container {
      background: #fff;
      padding: 25px 40px;
      margin: auto;
      width: 300px;
      box-shadow: 0 4px 8px rgba(0,0,0,0.2);
      border-radius: 10px;
    }
    h1 {
      font-size: 24px;
      margin-bottom: 20px;
    }
    input[type='text'], input[type='password'] {
      width: 100%;
      padding: 10px;
      margin: 10px 0 20px;
      border: 1px solid #ccc;
      border-radius: 5px;
    }
    input[type='submit'] {
      background-color: #4CAF50;
      color: white;
      border: none;
      padding: 12px 20px;
      border-radius: 5px;
      cursor: pointer;
      font-size: 16px;
    }
    input[type='submit']:hover {
      background-color: #45a049;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Wi-Fi Setup</h1>
    <form method="POST" action="/wifi-setup">
      <label for="ssid">SSID</label>
      <input type="text" id="ssid" name="ssid" maxlength="32" required>

      <label for="password">Password</label>
      <input type="password" id="password" name="password" maxlength="32">

      <input type="submit" value="Save">
    </form>
  </div>
</body>
</html>
)rawliteral";

    server.send(200, "text/html", page);
  });

  server.begin();
  Serial.println("HTTP server started.");
}

void handleWifiSetup() {
  if (!server.hasArg("ssid") || !server.hasArg("password")) {
    server.send(400, "text/plain", "Bad Request - Missing ssid or password");
    return;
  }

  String ssid = server.arg("ssid");
  String password = server.arg("password");

  Serial.printf("Received WiFi credentials: SSID=%s, PASS=%s\n", ssid.c_str(), password.c_str());

  saveCredentialsToEEPROM(ssid, password);
  server.send(200, "text/plain", "Credentials saved! Device will restart.");

  delay(1000);
  ESP.restart();
}

void handleResetWifi() {
  Serial.println("Resetting Wi-Fi credentials...");
  
  // Clear EEPROM Wi-Fi creds
  for (int i = 0; i < EEPROM_SIZE; i++) {
    EEPROM.write(i, 0);
  }
  EEPROM.commit();

  server.send(200, "text/plain", "Wi-Fi credentials reset! Restarting device...");

  delay(1000);
  ESP.restart();
}

void saveCredentialsToEEPROM(const String& ssid, const String& pass) {
  // Clear EEPROM first
  for (int i = 0; i < EEPROM_SIZE; i++) EEPROM.write(i, 0);

  for (int i = 0; i < ssid.length() && i < 32; i++) {
    EEPROM.write(EEPROM_SSID_ADDR + i, ssid[i]);
  }
  for (int i = 0; i < pass.length() && i < 32; i++) {
    EEPROM.write(EEPROM_PASS_ADDR + i, pass[i]);
  }
  EEPROM.commit();
}

bool loadCredentialsFromEEPROM(String& ssid, String& pass) {
  char ssid_buf[33];
  char pass_buf[33];

  for (int i = 0; i < 32; i++) {
    ssid_buf[i] = EEPROM.read(EEPROM_SSID_ADDR + i);
    pass_buf[i] = EEPROM.read(EEPROM_PASS_ADDR + i);
  }
  ssid_buf[32] = 0;
  pass_buf[32] = 0;

  ssid = String(ssid_buf);
  pass = String(pass_buf);

  ssid.trim();
  pass.trim();

  return (ssid.length() > 0);
}

void startStationMode() {
  // Init I2C for MAX30102 sensor
  Wire.begin();
  Wire.setClock(400000);

  if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("MAX30102 sensor not found. Check wiring!");
    while (true) delay(1000);
  }

  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeIR(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);

  Serial.println("Sensor initialized.");

  // Setup Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.print("Connecting to Firebase...");
  if (Firebase.ready()) {
    Serial.println("Firebase connected.");
  } else {
    Serial.println("Firebase connection failed.");
  }
}
