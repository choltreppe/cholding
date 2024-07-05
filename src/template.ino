#include <Keyboard.h>
#include <Keyboard_$locale.h>

typedef unsigned short int t_keys;


#define KEY_COUNT $key_count
const int key_pins[KEY_COUNT] = $key_pins;
const int key_levels[KEY_COUNT] = $key_levels;
const char basic_keys[KEY_COUNT] = $basic_keys;
const t_keys chord_mask = $chord_mask;
char chords[1 << KEY_COUNT] = {0};


#define DEBOUNCE_DELAY 30
#define CHORD_TIMEOUT 90

t_keys keys_pressed = 0;  // bit array

bool get_key(int id) {
  return bitRead(keys_pressed, id);
}

void set_key(int id, bool pressed) {
  static t_keys prev_keys = 0;
  static unsigned long debounce_time[KEY_COUNT] = {0};
  bool prev_pressed = bitRead(prev_keys, id);
  if(prev_pressed != pressed) {
    debounce_time[id] = millis();
    bitWrite(prev_keys, id, pressed);
  }
  else if(
    millis() - debounce_time[id] >= DEBOUNCE_DELAY &&
    prev_pressed != get_key(id)
  ){
    bitWrite(keys_pressed, id, pressed);
  }
}

void setup() {
  $init_chords

  for(int i = 0; i < KEY_COUNT; ++i) {
    if(key_levels[i])
      pinMode(key_pins[i], INPUT_PULLDOWN);
    else
      pinMode(key_pins[i], INPUT_PULLUP);
  }
  Keyboard.begin(KeyboardLayout_$locale);
}

void loop() {
  char prev_modifier = 0;  // for implementing modifier release on doublepress (0 if released)
  unsigned long int last_chord_time = 0;
  bool chord_started = false;
  while(true) {
    const bool chord_may_start = millis() - last_chord_time > CHORD_TIMEOUT;
    for(int i = 0; i < KEY_COUNT; ++i) {
      bool was_pressed = get_key(i);
      bool is_pressed = digitalRead(key_pins[i]) == key_levels[i];
      char basic_key = basic_keys[i];
      if(!was_pressed and is_pressed) {
        if(basic_key > 0)
          Keyboard.press(basic_key);
        else if(chord_may_start)
          chord_started = true;
      }
      else if(was_pressed and not is_pressed) {
        if(basic_key > 0)
          Keyboard.release(basic_key);
        else if(chord_started) {
          chord_started = false;
          last_chord_time = millis();
          t_keys chord = keys_pressed & chord_mask;
          char key_code = chords[chord];
          if(key_code > 0) {
            Keyboard.press(key_code);
            if(key_code >= KEY_LEFT_CTRL and key_code <= KEY_RIGHT_GUI and key_code != prev_modifier) {
              prev_modifier = key_code;
            }
            else {
              Keyboard.releaseAll();
              prev_modifier = 0;
            }
          }
        }
      }
      set_key(i, is_pressed);
    }
  }
}
