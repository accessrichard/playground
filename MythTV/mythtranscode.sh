#!/bin/bash
# ------------------------------------------------------------------                                                      
# [Author] Richard Kanavati                                                                                               
#          A simple MythTV script to transcode video to mkv                                                               
# ------------------------------------------------------------------                                                      

# ---------User Variable Defaults-----------------------------------                                                      
# For simplicity in configuring a MythTV user job, default command                                                        
# line parameters can be specified here.                                                                                  
# These will be overridden if you supply command line parameters.                                                          
db_user="mythtv"
db_password="mythtv"
output_dir="~/"
temp_dir="/tmp"
mythtranscode_options="--mpeg2 --honorcutlist"
ffmpeg_crf=23
ffmpeg_preset="slow"
limit_cpu=1
# ------------------------------------------------------------------                                                      

set -e
trap 'exit_handler' EXIT

exit_handler()
{
    if [ -e "$temp_transcoding_file" ]; then
        rm "$temp_transcoding_file"
    fi

    if [ -e "$temp_transcoding_file.map" ]; then
        rm "$temp_transcoding_file.map"
    fi
}

display_usage() {
    local directory="$(cd "$(dirname "${0}")"; echo $(pwd))"
    local file="${directory}/$(basename "${0}")"

    echo "Transcodes a video to .mkv auto cutting commercials."
    echo "User job example: $file -c %CHANID% -s %STARTTIMEUTC%"
    echo ""
    echo "-v         show version"
    echo "-h         show usage"
    echo "-l         limit CPU usage"
    echo "-s [arg]   starttime from mythtv. In user job %STARTTIMEUTC%"
    echo "-c [arg]   chanid from mythtv. In user job %CHANID%"
    echo "-u [arg]   MySql username"
    echo "-p [arg]   MySql password"
    echo "-o [arg]   output Directory"
    echo "-t [arg]   temp Directory"
    echo "-r [arg]   ffmpeg crf. See: https://trac.ffmpeg.org/wiki/Encode/H.264"
    echo "-z [arg]   ffmpeg preset. See: https://trac.ffmpeg.org/wiki/Encode/H.264"
}

if [ $# == 0 ] ; then
    display_usage
fi

while getopts ":s:c:u:p:o:t:r:z:vhl" optname
  do
    case "$optname" in
     v)
        echo "Version $VERSION"
        exit 0;;
      c)
        chanid=${OPTARG};;
      s)
        starttime=${OPTARG};;    
      l)
        limit_cpu=1;;
      m)
        db_user=${OPTARG};;
      p)
        db_password=${OPTARG};;
      o)
        output_dir=${OPTARG};;
      t)
        temp_dir=${OPTARG};;
      r)
        ffmpeg_crf=${OPTARG};;
      z)
        ffmpeg_preset=${OPTARG};;
      h)
        display_usage;
        exit 0;;
    esac
  done

if [ -z "$chanid" ] || [ -z "$starttime" ]; then
  echo
  echo "Must supply -c and -s parameters!";
  echo
  display_usage
  exit 1
fi

if [ "$limit_cpu" -eq 1 ]; then
    renice 19 $$
    ionice -c 3 -p $$
fi

sql="                                                                                                                     
SELECT                                                                                                                    
    s.dirname as storagegroup,                                                                                            
    r.basename,                                                                                                           
    r.commflagged,                                                                                                        
    CONCAT(r.title,' ', CASE                                                                                              
                         WHEN r.season > 0                                                                                
                         THEN concat('s', lpad(r.season,2,0), 'e', lpad(r.episode,2,0), ' ')                              
                         ELSE ''                                                                                          
                        END, r.subtitle) AS title                                                                         
FROM                                                                                                                      
    recorded r                                                                                                            
    JOIN storagegroup s                                                                                                   
       ON s.groupname = r.storagegroup                                                                                    
WHERE                                                                                                                     
   r.chanid = '$chanid'                                                                                                   
   and r.starttime='$starttime'                                                                                           
LIMIT 1;                                                                                                                  
"

query_results=$(mysql -u"$db_user" -p"$db_password" -Dmythconverg -NBse  "$sql")
if [ ! "$query_results" ]; then
    echo "Could not locate video in the mythtv database."
    exit 1
fi

storage_group=$(echo "$query_results"|cut -f1)
if [ ! "$storage_group" ]; then
    echo "Could not locate storage group in the mythtv database."
    exit 1
fi

basename=$(echo "$query_results"|cut -f2)
commflagged=$(echo "$query_results"|cut -f3)
title=$(echo "$query_results"|cut -f4|sed 's/ *$//'|sed "s/[:?]/ /g"|sed "s/[.]//g")
if [ ! "$title" ]; then
    title="unknown_title_${starttime}"
fi

transcoding_file="$storage_group$basename"
temp_transcoding_file="$temp_dir/${chanid}_$starttime.mpg"
output_file="$output_dir/$title.mkv"
if [ -e "$output_file" ]; then
   output_file="$output_dir/${title}_$starttime.mkv"
fi

if [ $commflagged -eq 0 ]; then
    /usr/bin/mythcommflag --chanid "$chanid" --starttime "$starttime"
fi

/usr/bin/mythutil --chanid "$chanid" --starttime "$starttime" --gencutlist
/usr/bin/mythtranscode --chanid "$chanid" --starttime "$starttime" --allkeys --buildindex --mpeg2 --showprogress
/usr/bin/mythtranscode --chanid "$chanid" --starttime "$starttime" $mythtranscode_options -o "$temp_transcoding_file"
/usr/bin/mythcommflag --file "$temp_transcoding_file" --rebuild
/usr/bin/ffmpeg -i "$temp_transcoding_file" -c:v libx264 -preset "$ffmpeg_preset" -crf "$ffmpeg_crf" -c:a copy "$output_file"