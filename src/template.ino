#include <Keyboard.h>

typedef unsigned short int t_keys;


#define KEY_COUNT $key_count
const int key_pins[KEY_COUNT] = $key_pins;
const int key_levels[KEY_COUNT] = $key_levels;
const char basic_keys[KEY_COUNT] = $basic_keys;
const t_keys chord_mask = $chord_mask;
char chords[1 << KEY_COUNT] = {0};


#define DEBOUNCE_DELAY 40

t_keys keys_pressed = 0;  // bit array 
bool chord_started = false;

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
  Keyboard.begin();
}

void loop() {
  while(true) {
    for(int i = 0; i < KEY_COUNT; ++i) {
      bool was_pressed = get_key(i);
      bool is_pressed = digitalRead(key_pins[i]) == key_levels[i];
      char basic_key = basic_keys[i];
      if(!was_pressed && is_pressed) {
        if(basic_key > 0)
          Keyboard.press(basic_key);
        chord_started = true;
      }
      else if(was_pressed && !is_pressed) {
        if(basic_key > 0)
          Keyboard.release(basic_key);
        else if(chord_started) {
          chord_started = false;
          t_keys chord = keys_pressed & chord_mask;
          char key_code = chords[chord];
          if(key_code > 0) {
            Keyboard.press(key_code);
            Keyboard.release(key_code);
          }
        }
      }
      set_key(i, is_pressed);
    }
  }
}
