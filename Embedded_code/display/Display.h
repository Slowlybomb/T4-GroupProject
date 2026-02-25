#include <Adafruit_ILI9341.h>
#include <icons.h>
void show_ui(Adafruit_ILI9341 tft) {
  tft.drawBitmap(290, 9, image_battery_full_bits, 24, 13, 0xFFFF);
  tft.drawLine(1, 29, 319, 29, 0xFFFF);
  tft.drawLine(0, 169, 319, 169, 0xFFFF);
  tft.drawLine(-2, 239, 318, 239, 0xFFFF);
  tft.drawLine(319, 0, 319, 239, 0xFFFF);
  tft.drawLine(0, 0, 319, 0, 0xFFFF);
  tft.drawLine(0, -1, 0, 239, 0xFFFF);

  tft.setTextColor(0xFFFF);
  tft.setTextSize(20);
  tft.setTextWrap(false);
  tft.setFont(&Org_01);
  tft.setCursor(108, 126);
  tft.print("0");

  tft.setTextSize(4);
  tft.setCursor(22, 205);
  tft.print("0:00");

  tft.setTextSize(2);
  tft.setFont();
  tft.setCursor(276, 150);
  tft.print("S/M");

  tft.setTextSize(3);
  tft.setFont(&Org_01);
  tft.setCursor(186, 202);
  tft.print("00:00:00");

  tft.setTextSize(2);
  tft.setFont();
  tft.setCursor(218, 218);
  tft.print("Elapsed");

  tft.setCursor(23, 219);
  tft.print("split");

  tft.setFont(&Org_01);
  tft.setCursor(13, 20);
  tft.print("0:00");

  tft.drawBitmap(258, 7, image_wifi_bits, 19, 16, 0xFFFF);
}

void splashscreen(Adafruit_ILI9341& tft) {
  display.drawBitmap(34, -40, image_gondolier_hat_bits, 255, 240, 0xFFFF);

  display.setTextColor(0xFFFF);
  display.setTextSize(4);
  display.setTextWrap(false);
  display.setCursor(55, 203);
  display.print("Gondolier");
}

void update_timer(Adafruit_ILI9341& tft, String time) {
  tft.fillRect(186, 186, 130, 26, 0x0000);
  tft.setTextSize(3);
  tft.setFont(&Org_01);
  tft.setCursor(186, 202);
  tft.print(time);
}

void update_split(Adafruit_ILI9341& tft, String split) {
  tft.fillRect(4, 186, 106, 26, 0x0000);
  tft.setTextSize(4);
  tft.setFont(&Org_01);
  tft.setCursor(22, 205);
  tft.print(split);
}

void update_strokes(Adafruit_ILI9341& tft, String strokes) {
  tft.fillRect(44, 44, 240, 102, 0x0000);
  tft.setTextColor(0xFFFF);
  tft.setTextSize(20);
  tft.setFont(&Org_01);
  if (strokes.length() < 2) {
    if (strokes == "1") {
      tft.setCursor(148, 126);
    }
    else {
      tft.setCursor(108, 126);
    }
  }
  else {
    if (strokes[0] == '1') {
      if (strokes[1] == '1') {
        tft.setCursor(124, 126);
      }
      else {
        tft.setCursor(84, 126);
      }
    }
    else {
      if (strokes[1] == '1') {
        tft.setCursor(84, 126);
      }
      else {
        tft.setCursor(44, 126);
      }
    }
  }
  tft.print(strokes);
}

void update_screen(Adafruit_ILI9341& tft, String strokes, String split, String time) {
  update_strokes(tft, strokes);
  update_split(tft, split);
  update_timer(tft, time);
}
