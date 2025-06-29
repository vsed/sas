#!/bin/bash

insert_logo="$HOME/Videos/bskk/YT_Title_Logo.png"
font_file="$HOME/Videos/bskk/FanwoodText-Regular.ttf"
udalost="Nedělní shromáždění"

if [ $# -lt 8 ]; then
    echo usage: "$0" videofile start-time end-time title preacher text date udalost [video filters]
    echo example: "$0" 'bskk-recording.mp4 00:00:19 00:47:13 "Otec smrti, Otec života" "Marcus Denny" "Římanům 5,12–14" "25.6.2023" "Nedělní shromáždění" "eq=saturation=1.7"'
    exit 1
fi

video="$1"
start="$2"
end="$3"
title="$4"
preacher="$5"
text="$6"
date="$7"
udalost="$8"
videofilters="$9"

if [ -n "$videofilters" ];then videofilters="${videofilters},";fi
fps=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "${video}")
resolution=$(ffprobe -v 0 -of csv=s=x:p=0 -select_streams v:0 -show_entries stream=width,height "${video}")
audio_rate="$(ffprobe -v 0 -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 ${video})"

### FORMAT DATE TO OUTPUT FILENAME:
IFS='.' read -r day month year <<< "$date"
formatted_date="${year}-$(printf %02d "$month")-$(printf %02d "$day")"
date_in_name="$(date -d "$formatted_date" +'%Y.%m.%d')"

### NAME OF THE OUTPUT FILE
output_name="${date_in_name}-${title}-${preacher}-${text}.mp4"
output_name_a="${date_in_name}-${title}-${preacher}-${text}.mp3"

### TITLE AND DESCRIPTION FOR YOUTUBE:
yt_desc="title:
$title ($text)
description:
Kazatel: $preacher
Událost: $udalost
Datum: $date
Text: $text"

############ GENERATE LOGO.PNG #################
# Create a blank white image
convert -define png:color-type=6 -size "$resolution" xc:white blank.png

# Calculate the center position
read width height < <(identify -format "%w %h" blank.png)
read res_width res_height < <(identify -format "%w %h" "$insert_logo")
offset_x=$(((width - res_width) / 2))
offset_y=$(((height - res_height) / 2))

# Composite the resized image onto the blank image
composite -gravity center "$insert_logo" blank.png -define png:color-type=6 logo.png

############# GENERATE DESC.PNG ##################
### CONTAINS SERMON TITLE, PREACHER, DATE, ...
background_color="white"
font_size=$((width / 22))
title_font_size=$((width / 18))

# Calculate text positions
title_y=-$((height / 7))
preacher_y=$((height * 10 / 65))
text_y=$((height * 10 / 36))
date_y=$((height * 10 / 25))

# Generate image with text
convert -size "${width}x${height}" "xc:${background_color}" \
  -font "$font_file" -pointsize $title_font_size -fill black -gravity center \
  -annotate +0+"$title_y" "$title" \
  -font "$font_file" -pointsize $font_size -fill black -gravity center \
  -annotate +0+"$preacher_y" "$preacher" \
  -font "$font_file" -pointsize $font_size -fill black -gravity center \
  -annotate +0+"$text_y" "$text" \
  -font "$font_file" -pointsize $font_size -fill black -gravity center \
  -annotate +0+"$date_y" "$date" \
  desc.png

###### GENERATE WHITE.PNG ######
convert -define png:color-type=6 -size $resolution xc:white white.png
################################


############# CONVERT TIME TO SECONDS ###################
time_to_s() {
  local time="$1"

  # Splitting the time string into separate components
  hours=10#$(echo "$time" | cut -d ':' -f 1)
  minutes=10#$(echo "$time" | cut -d ':' -f 2)
  seconds=10#$(echo "$time" | cut -d ':' -f 3 | cut -d '.' -f 1)

  # Checking if deciseconds are provided
  if echo "$time" | grep -q '\.'; then
    deciseconds=10#$(echo "$time" | cut -d '.' -f 2)
  else
    deciseconds=0
  fi

  # Converting time to seconds.deciseconds
  total_seconds="$((hours * 3600 + minutes * 60 + seconds))"
  converted_time="${total_seconds}.${deciseconds}"

  echo "$converted_time"
}
###########################################################

logo_offset=0.5
logo_fade=1
logo_duration=1
w2_offset=$(echo $logo_offset + $logo_fade + $logo_duration|bc)
w2_fade=0.6
w2_duration=0.4
desc_offset=$(echo $w2_offset + $w2_fade + $w2_duration|bc)
desc_fade=0.6
desc_duration=3
w3_offset=$(echo $desc_offset + $desc_fade + $desc_duration|bc)
w3_fade=1
w3_duration=0.5
sermon_offset=$(echo $w3_offset + $w3_fade + w3_duration|bc)
sermon_fade=0.8
sermon_duration=$(echo "$(time_to_s $end)" - "$(time_to_s "$start")" |bc)
logo2_offset=$(echo "$sermon_offset" + "$sermon_fade" + "$sermon_duration"|bc)
logo2_fade=1
logo2_duration=3
end_offset="$(echo $logo2_offset + $logo2_fade + $logo2_duration|bc)"

start_s=$(time_to_s "$start")
end_s=$(echo "$(time_to_s $end)" + 1|bc)

### DEBUG ECHO ###

echo "
video: $video
fps: $fps
resolution: $resolution
videofilters: $videofilters

"

##################

if [ "${video##*.}" = "braw" ];then
command="braw-decode $video|pv -qL 130M|ffmpeg -y -vaapi_device /dev/dri/renderD128 -r $fps -i white.png -r $fps -i white.png -r $fps -i white.png -r $fps -i logo.png -r $fps -i logo.png -r $fps -i desc.png -f rawvideo -pixel_format rgba -s $resolution -thread_queue_size 1024 -r $fps -i pipe:0 -i $video -filter_complex \"[7:a]anull[6:a];\
"
else
command="ffmpeg -y -framerate $fps -i logo.png -framerate $fps -i desc.png -i ${video} -filter_complex \""
fi


filter_complex="\
color=white:$resolution:d=12,fps=$fps[white_start];

[0:v]split[start_logo][end_logo];

[start_logo]loop=-1:1,format=rgb24,fade=in:st=$logo_offset:d=$logo_fade:alpha=1,
fade=out:st=$w2_offset:d=$w2_duration:alpha=1,trim=start=0:end=$desc_offset,fps=$fps[logo_start];

[1:v]loop=-1:1,format=rgb24,fade=in:st=$desc_offset:d=$desc_fade:alpha=1,
fade=out:st=$w3_offset:d=$w3_fade:alpha=1,trim=start=0:end=$(echo $sermon_offset + 1|bc ),fps=$fps[desc];

[2:v]trim=start=$start_s:end=$(echo "$end_s" + 1|bc),setpts=PTS-STARTPTS+$sermon_offset/TB,
normalize=blackpt=black:whitept=white:independence=0:smoothing=50,${videofilters}
fade=in:st=$sermon_offset:d=$sermon_fade:alpha=1[sermon];

[end_logo]loop=-1:1,format=rgb24,fade=in:st=$logo2_offset:d=$logo2_fade:alpha=1,
trim=start=$logo2_offset:end=$end_offset,fps=$fps[logo_end];


aevalsrc=0:d=$(echo "$sermon_offset" + "$sermon_fade"|bc)[silence];

[2:a]atrim=start=$(echo "$start_s" - 0|bc),
afade=t=in:st=0:d=$sermon_fade,afade=t=out:st=$(echo "$end_s" - 1|bc):d=$logo2_fade,
atrim=end=$end_s,asplit=2[sermon_a][sermon_a2];

[silence][sermon_a]acrossfade=d=$sermon_fade[audio];


[white_start][logo_start]overlay[afterlogo];
[afterlogo][desc]overlay[afterdesc];
[afterdesc][sermon]overlay[aftersermon];
[aftersermon][logo_end]overlay,


format=p010,hwupload"


output="-map [audio] -vaapi_device /dev/dri/renderD128 -c:v hevc_vaapi -b:v 20M -profile:v 2 -c:a aac -b:a 288k -ar $audio_rate \"$output_name\" -map [sermon_a2] -c:a libmp3lame -qscale:a 4 \"$output_name_a\""

echo "$yt_desc" > "${output_name}.txt"

eval "nice -n 19 $command" "$filter_complex\"" "$output"
