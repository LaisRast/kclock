#!/bin/sh

set -e

# timezone
export TZ="CET-1CEST,M3.5.0/2,M10.5.0/3" # Eurpoe/Berlin

# define the input files and the output file
TEMPLATE_FILE="template.svg"
OUTPUT_SVG_FILE="../output/image.svg"
OUTPUT_PNG_FILE="../output/image.png"
OUTPUT_OPTIMIZED_PNG_FILE="../output/image_optimized.png"
EXIT_FILE="../output/EXIT"

stop_framework() {
  /etc/init.d/framework stop
  /usr/bin/lipc-set-prop com.lab126.powerd preventScreenSaver 1
  /usr/bin/lipc-set-prop com.lab126.wifid enable 0
}

start_framework() {
  /usr/bin/lipc-set-prop -- com.lab126.powerd preventScreenSaver 0
  /etc/init.d/framework start
}

get_battery_level() {
  gasgauge-info -c | sed 's/.$//'
}

build_svg() {
  # hours and minutes
  HOURS=$(date +%-H)
  MINUTES=$(date +%-M)
  HOURS_ANGLE=$(((HOURS % 12) * 30 + MINUTES / 2))
  MINUTES_ANGLE=$((MINUTES * 6))
  HOURS_PADDED=$(printf "%02d" $HOURS)
  MINUTES_PADDED=$(printf "%02d" $MINUTES)

  # date and weekday
  DATE=$(date +"%d %B %Y")
  WEEKDAY=$(date +"%A")

  # battery level
  BATTERY_LEVEL=$(get_battery_level)
  BATTERY_WIDTH=$((BATTERY_LEVEL + BATTERY_LEVEL))

  # render
  TEMPLATE=$(cat "$TEMPLATE_FILE")
  OUTPUT_SVG=$(echo "$TEMPLATE" |
    sed \
      -e "s/BATTERY_WIDTH/$BATTERY_WIDTH/" \
      -e "s/BATTERY_LEVEL/$BATTERY_LEVEL/" \
      -e "s/WEEKDAY/$WEEKDAY/" \
      -e "s/DATE/$DATE/" \
      -e "s/HOURS_ANGLE/$HOURS_ANGLE/" \
      -e "s/MINUTES_ANGLE/$MINUTES_ANGLE/" \
      -e "s/HOURS/$HOURS_PADDED/" \
      -e "s/MINUTES/$MINUTES_PADDED/")
  echo "$OUTPUT_SVG" >"$OUTPUT_SVG_FILE"
}

build_png() {
  ../third_party/rsvg-convert --background-color=white -o $OUTPUT_PNG_FILE $OUTPUT_SVG_FILE
  ../third_party/pngcrush -c 0 $OUTPUT_PNG_FILE $OUTPUT_OPTIMIZED_PNG_FILE
}

process_key() {
  while true; do
    [ "$(waitforkey)" = "102 1" ] && touch "$EXIT_FILE" && start_framework && exit 0
  done
}

print_clock() {
  build_svg
  build_png
  eips -c
  eips -g $OUTPUT_OPTIMIZED_PNG_FILE
}

print_clock_loop() {
  while true; do
    [ -f "$EXIT_FILE" ] && exit 0
    print_clock
    sleep 60
  done
}

main() {
  cd "$(dirname "$0")"
  [ -f "$EXIT_FILE" ] && rm "$EXIT_FILE"
  stop_framework
  print_clock
  process_key &
  print_clock_loop &
}

main
