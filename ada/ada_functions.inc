# available as ada/ada.inc

#
# Define functions ada needs.
#


urlencode () {
  # We use jq for encoding the URL, because we need jq anyway.
  $debug && echo "urlencoding '$1' to '$(printf '%s' "$1" | jq -sRr @uri)'" 1>&2
  printf '%s' "$1" | jq -sRr @uri
}


pathtype () {
  # Get the type of an object. Possible outcomes:
  # DIR     = directory
  # REGULAR = file
  # LINK    = symbolic link
  # <empty> = something went wrong... no permission?
  local path=$(urlencode "$1")
  command='curl "${curl_authorization[@]}" \
       "${curl_options_no_errors[@]}" \
       -X GET "$api/namespace/$path" \
  | jq -r .fileType'
  if $dry_run ; then
    echo "$command"
  else
    eval "$command"
  fi
}


get_pnfsid () {
  local path=$(urlencode "$1")
  command='curl "${curl_authorization[@]}" \
       "${curl_options_no_errors[@]}" \
       -X GET "$api/namespace/$path" \
  | jq -r .pnfsId'
  if $dry_run ; then
    echo "$command"
  else
    eval "$command"
  fi
}


is_online () {
  # Checks whether a file is online.
  # The locality should be ONLINE or ONLINE_AND_NEARLINE.
  local path=$(urlencode "$1")
  command='curl "${curl_authorization[@]}" \
       "${curl_options_no_errors[@]}" \
       -X GET "$api/namespace/$path?locality=true&qos=true" \
  | jq -r ".fileLocality" \
  | grep --silent "ONLINE"'
  if $dry_run ; then
    echo "$command"
  else
    eval "$command"
  fi  
}


get_subdirs () {
  local path=$(urlencode "$1")
  str='.children | .[] | if .fileType == "DIR" then .fileName else empty end'
  command='curl "${curl_authorization[@]}" \
       "${curl_options_common[@]}" \
       -X GET "$api/namespace/$path?children=true" \
  | jq -r "$str"'
  if $dry_run ; then
    echo "$command"
  else
    eval "$command"
  fi    
}


get_files_in_dir () {
  local path=$(urlencode "$1")
  str='.children | .[] | if .fileType == "REGULAR" then .fileName else empty end'
  command='curl "${curl_authorization[@]}" \
       "${curl_options_common[@]}" \
       -X GET "$api/namespace/$path?children=true" \
  | jq -r "$str"'
  if $dry_run ; then
    echo "$command"
  else
    eval "$command"
  fi    
}


get_children () {
  local path
  path=$(urlencode "$1")
  curl "${curl_authorization[@]}" \
       "${curl_options_common[@]}" \
       -X GET "$api/namespace/$path?children=true" \
  | jq -r '.children | .[] | .fileName'
}


dir_has_items () {
  path="$1"
  get_children "$path" | grep --silent --max-count 1 '.'
}


get_confirmation () {
  prompt="$1"
  while true ; do
    # We read the answer from tty, otherwise strange things would happen.
    read -r -p "$prompt (N/y) " -n1 answer < /dev/tty
    echo
    case $answer in
      Y | y )       return 0  ;;
      N | n | '' )  return 1  ;;
    esac
  done
}


create_path () {
  let counter++
  if [ $counter -gt 10 ] ; then
    echo 1>&2 "ERROR: max number of directories that can be created at once is 10."
    exit 1  
  fi
  local path="$1"
  local recursive="$2"
  local parent="$(dirname "$path")"
  get_locality "$parent"
  error=$?
  if [ $error == 1 ] && $recursive ; then
    if [ "${#parent}" -gt 1 ]; then
      echo 1>&2 "Warning: parent dir '$parent' does not exist. Will atempt to create it."
      create_path $parent $recursive
    else
      echo 1>&2 "ERROR: Unable to create dirs. Check the specified path."
      exit 1
    fi
  elif [ $error == 1 ]; then 
    echo 1>&2 "ERROR: parent dir '$parent' does not exist. To recursivly create dirs, add --recursive."
    exit 1
  fi 
  parent=$(urlencode "$(dirname "$path")")
  name=$(basename "$path")
  (
    $debug && set -x   # If --debug is specified, show (only) curl command
    curl "${curl_authorization[@]}" \
          "${curl_options_common[@]}" \
          "${curl_options_post[@]}" \
          -X POST "$api/namespace/$parent" \
          -d "{\"action\":\"mkdir\",\"name\":\"$name\"}"
  ) \
  | jq -r .status
}


delete_path () {
  local path="$1"
  local recursive="$2"
  local force="$3"
  case $recursive in
    true | false ) ;;  # No problem
    * )
      echo 1>&2 "ERROR: delete_path: recursive is '$recursive' but should be true or false."
      exit 1
      ;;
  esac
  path_type=$(pathtype "$path")
  if [ -z "$path_type" ] ; then
    # Could be a permission problem.
    echo "Warning: could not get object type of '$path'."
    # Quit the current object, but don't abort the rest
    return 0
  fi
  local aborted=false
  # Are there children in this path we need to delete too?
  if $recursive && [ "$path_type" = "DIR" ] ; then
    if $force || get_confirmation "Delete all items in $path?" ; then
      while read -r child ; do
        delete_path "$path/$child" "$recursive" "$force" \
        || aborted=true
      done < <(get_children "$path")
    else
      # If the user pressed 'n', dir contents will not be deleted;
      # In that case we should not delete the dir either.
      aborted=true
    fi
  fi
  # Done with the children, now we delete the parent (if not aborted).
  if $aborted ; then
    echo "Deleting $path - aborted."
    # Tell higher level that user aborted,
    # because deleting the parent dir is useless.
    return 1  
  else
    echo -n "Deleting $path - "
    encoded_path=$(urlencode "$path")
    (
      $debug && set -x
      curl "${curl_authorization[@]}" \
           "${curl_options_common[@]}" \
           -X DELETE "$api/namespace/$encoded_path"
    ) \
    | jq -r .status
  fi
}


get_locality () {
  local path="$1"
  $debug || echo -n "$file  "
  locality="$((\
    $debug && set -x   # If --debug is specified, show (only) curl command
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         "${curl_options_post[@]}" \
         -X POST "$api/tape/archiveinfo" \
         -d "{\"paths\":[\"/${path}\"]}" \
  ) | jq . | grep locality)"
  if [ -z "$locality" ] ; then
    return 1
  else
    return 0
  fi
}


bulk_request() {
  local activity="$1"
  local pathlist="$2"
  local recursive="$3"
  if [ "$from_file" == false ] ; then
    local filepath="$2"
    get_locality "$filepath"
    error=$?
    if [ "$error" == 1 ] ; then
      echo 1>&2 "Error: '$filepath' does not exist."
      exit 1
    fi
    type=$(pathtype "$filepath")
    case $type in
      DIR )
        if $recursive ; then
          expand=ALL
        else
          expand=TARGETS
        fi
        ;;
      REGULAR | LINK )
        expand=NONE
        ;;
      '' )
        echo "Warning: could not determine object type of '$filepath'."
        ;;
      * )
        echo "Unknown object type '$type'. Please create an issue for this in Github."
        ;;
    esac
  else
    if $recursive ; then
      echo 1>&2 "Error: recursive (un)staging forbidden when using file-list."
      exit 1
    else
      expand=TARGETS
    fi
  fi
  case $activity in
    PIN   )    
      arguments="{\"lifetime\": \"${lifetime}\", \"lifetimeUnit\":\"${lifetime_unit}\"}" ;;
    UNPIN )    
      arguments="{}" ;;
  esac
  target='['
  while read -r path ; do
    target=$target\"/${path}\",
  done <<<"$pathlist"
  target=${target%?}]
  data="{\"activity\": \"${activity}\", \"arguments\": ${arguments}, \"target\": ${target}, \"expand_directories\": \"${expand}\"}"
  $debug || echo "$target  "
  (
    $debug && set -x   # If --debug is specified, show (only) curl command 
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         "${curl_options_post[@]}" \
         -X POST "$api/bulk-requests"\
         -d "${data}" \
         --dump-header - 
  ) | grep -e request-url -e Date | tee -a "${requests_log}"
  $debug && echo "Information about bulk request is logged in $requests_log."
  echo "activity: $activity" >> $requests_log
  echo "target: $target" | sed 's/,/,\n         /g' >> $requests_log
  echo " " >> $requests_log
}


with_files_in_dir_do () {
  # This will execute a function on all files in a dir.
  # Recursion into subdirs is supported.
  #
  # Arguments:
  # 1. The function to be executed on files;
  # 2. The dir to work on
  # 3. Recursive? (true|false)
  # 3-x. Additional arguments to give to the function
  #      (The first argument to the function is always the file name.)
  #
  local function="$1"
  local path="$2"
  local recursive="$3"
  case $recursive in
    true | false )  ;;  # No problem
    * )
      echo 1>&2 "Error in with_files_in_dir_do: recursive='$recursive'; should be true or false."
      exit 1
      ;;
  esac
  shift ; shift ; shift
  # Run the given command on all files in this directory
  get_files_in_dir "$path" \
  | while read -r filename ; do
    "$function" "$path/$filename" "$@"
  done
  # If needed, do the same in subdirs
  if $recursive ; then
    get_subdirs "$path" \
    | while read -r subdir ; do
      with_files_in_dir_do "$function" "$path/$subdir" "$recursive" "$@"
    done
  fi
}


get_checksums () {
  # This function prints out all known checksums of a given file.
  # A file can have Adler32 checksum, MD5 checksum, or both.
  # Output format:
  # /path/file  ADLER32=xxx  MD5_TYPE=xxxxx
  local path="$1"
  encoded_path=$(urlencode "$path")
  {
    echo -n -e "$path\t"
    pnfsid=$(get_pnfsid "$path")
    if [ -z "$pnfsid" ] ; then
      echo "Could not get pnfsid."
      return
    fi
    {
      curl "${curl_authorization[@]}" \
           "${curl_options_no_errors[@]}" \
           -X GET "$api/id/$pnfsid" \
      | jq -r '.checksums | .[] | [ .type , .value ] | @tsv'
      # jq output is tab separated:
      # ADLER32\txxx
      # MD5_TYPE\txxxxx
    } \
    | sed -e 's/\t/=/g' | tr '\n' '\t'
    echo
  } \
  | sed -e 's/\t/  /g'
}


get_channel_by_name () {
  local channelname="$1"
  # Many other API calls depend on this one.
  # So if this one fails, we quit the script.
  channel_json=$(
                  $debug && set -x
                  curl "${curl_authorization[@]}" \
                       "${curl_options_common[@]}" \
                       -X GET "$api/events/channels?client-id=$channelname"
                ) \
                || {
                     echo "ERROR: unable to check for channels." 1>&2
                     exit 1
                   }
  channel=$(jq -r '.[]' <<<"$channel_json")
  channel_count=$(wc -l <<<"$channel")
  if [ "$channel_count" -gt 1 ] ; then
    echo 1>&2 "ERROR: there is more than one channel with that name:"
    echo "$channel"
    exit 1
  fi
  echo "$channel"
}

get_channels () {
  local channelname="$1"
  local query=''
  if [ -n "$channelname" ] ; then
    query="?client-id=$channelname"
  fi
  (
    $debug && set -x
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         -X GET "$api/events/channels${query}"
  ) \
  | jq -r '.[]'
}

channel_subscribe () {
  local channel="$1"
  local path="$2"
  local recursive="$3"
  (
    $debug && set -x
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         "${curl_options_post[@]}" \
         -X POST "$channel/subscriptions/inotify" \
         -d "{\"path\":\"$path\"}"
  )
  if $recursive ; then
    get_subdirs "$path" \
    | while read -r subdir ; do
      $debug && echo "Subscribing to: $path/$subdir"
      channel_subscribe "$channel" "$path/$subdir" "$recursive"
    done
  fi
}


get_subscriptions_by_channel () {
  local channel="$1"
  (
    $debug && set -x
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         -X GET "$channel/subscriptions"
  ) \
  | jq -r '.[]'
}


list_subscription () {
  # Shows all properties of a subscription. (Could be only a path.)
  local subscription="$1"
  (
    $debug && set -x
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         -X GET "$subscription"
  ) \
  | jq -r 'to_entries[] | [.key, .value] | @tsv' \
  | tr '\t' '='
}


get_path_from_subscription () {
  local subscription="$1"
  (
    $debug && set -x
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         -X GET "$subscription"
  ) \
  | jq -r .path
}


follow_channel () {
  # This function is used for two commands: --events and --report-staged.
  # Much of the functionality is the same, but
  # with --report-staged we're checking only whether files
  # are being brought online.
  local channel="$1"
  declare -A subscriptions
  channel_id=$(basename "$channel")
  channel_status_file="${ada_dir}/channels/channel-status-${channel_id}"
  # If a file exists with the last event for this channel,
  # We should resume from that event ID.
  if [ -f "$channel_status_file" ] ; then
    last_event_id=$(grep -E --max-count=1 --only-matching \
                         '[0-9]+' "$channel_status_file")
    if [ -n "$last_event_id" ] ; then
      echo "Resuming from $last_event_id"
      last_event_id_header=(-H "Last-Event-ID: $last_event_id")
    fi
  else
    last_event_id_header=()
  fi
  (
    $debug && set -x
    curl "${curl_authorization[@]}" \
         "${curl_options_stream[@]}" \
         -X GET "$channel" \
         "${last_event_id_header[@]}"
  ) \
  | while IFS=': ' read -r key value ; do
      case $key in
        event )
          case $value in
            inotify | SYSTEM )
              event_type="$value"
              ;;
            * )
              echo 1>&2 "ERROR: don't know how to handle event type '$value'."
              cat  # Read and show everything from stdin
              exit 1
              ;;
          esac
          ;;
        id )
          # Save event number so we can resume later.
          event_id="$value"
          ;;
        data )
          case $event_type in
            inotify )
              $debug && { echo ; echo "$value" | jq --compact-output ; }
              # Sometimes there's no .event.name: 
              # then 'select (.!=null)' will output an empty string.
              object_name=$(jq -r '.event.name | select (.!=null)' <<< "$value")
              mask=$(jq -r '.event.mask | @csv' <<< "$value" | tr -d '"')
              cookie=$(jq -r '.event.cookie | select (.!=null)' <<<"$value")
              subscription=$(jq -r '.subscription' <<< "$value")
              subscription_id=$(basename "$subscription")
              # We want to output not only the file name, but the full path.
              # We get the path from the API, but we cache the result
              # in an array for performance.
              if [ ! ${subscriptions[$subscription_id]+_} ] ; then
                # Not cached yet; get the path and store it in an array.
                subscriptions[$subscription_id]=$(get_path_from_subscription "$subscription")
              fi
              path="${subscriptions[$subscription_id]}"
              #
              # If recursion is requested, we need to start following new directories.
              if $recursive ; then
                if [ "$mask" = "IN_CREATE,IN_ISDIR" ] ; then
                  channel_subscribe "$channel" "$path/$object_name" "$recursive"
                fi
              fi
              #
              # A move or rename operation consists of two events,
              # an IN_MOVED_FROM and an IN_MOVED_FROM, both with
              # a cookie (ID) to relate them.
              if [ -n "$cookie" ] ; then
                cookie_string="  cookie:$cookie"
              else
                cookie_string=
              fi
              # Is the user doing --events or --report-staged? The output differs a lot.
              case $command in
                events )
                  # Here comes the output.
                  echo -e "$event_type  ${path}/${object_name}  ${mask}${cookie_string}"
                  ;;
                report-staged )
                  # User wants to see only the staged files.
                  path_type=$(pathtype "${path}/${object_name}")
                  case $path_type in
                    REGULAR )
                      # Is it an attribute event?
                      if grep --silent -e IN_ATTRIB -e IN_MOVED_TO <<<"$mask" ; then
                        # Show file properties (locality, QoS, name)
                        encoded_path=$(urlencode "${path}/${object_name}")
                        (
                          $debug && set -x   # If --debug is specified, show (only) curl command
                          curl "${curl_authorization[@]}" \
                               "${curl_options_common[@]}" \
                               -X GET "$api/namespace/$encoded_path?locality=true&qos=true"
                        ) \
                        | jq -r '[ .fileLocality ,
                                   if .targetQos then (.currentQos + "→" + .targetQos) else .currentQos end ,
                                   "'"${path}/${object_name}"'" ]
                                 | @tsv' \
                        | sed -e 's/\t/  /g'
                      fi
                      ;;
                    '' )
                      # File may have been deleted or moved
                      echo "WARNING: could not get object type of ${path}/${object_name}." \
                           "It may have been deleted or moved."
                      ;;
                  esac
                  ;;
              esac
              #
              # When done with this event's data, save the event ID.
              # This can be used to resume the channel.
              echo "$event_id" > "$channel_status_file"
              ;;
            SYSTEM )
              # For system type events we just want the raw output.
              echo -e "$event_type  $value"              
              ;;
            '' )
              # If we get a data line that was not preceded by an 
              # event line, something is wrong.
              echo "Unexpected data line: '$value' near event ID '$event_id'."
              ;;
          esac
          ;;
        '' )
          # Empty line: this ends the current event.
          event_type=
          ;;
        * )
          echo 1>&2 "ERROR: don't know how to handle '$key: $value'."
          exit 1
          ;;
      esac
  done
}


list_online_files () {
  local path="$1"
  local recursive="$2"
  case $recursive in
    true | false ) ;;  # No problem
    * )
      echo 1>&2 "ERROR: list_online_files: recursive is '$recursive' but should be true or false."
      exit 1
      ;;
  esac
  # Show online files in this dir with locality and QoS
  encoded_path=$(urlencode "$path")
  (
    $debug && set -x   # If --debug is specified, show (only) curl command
    curl "${curl_authorization[@]}" \
         "${curl_options_common[@]}" \
         -X GET "$api/namespace/$encoded_path?children=true&locality=true&qos=true"
  ) \
  | jq -r '.children 
           | .[]
           | if .fileType == "REGULAR" then . else empty end
           | [ .fileLocality ,
               if .targetQos then (.currentQos + "→" + .targetQos) else .currentQos end ,
               "'"$path"'/" + .fileName ]
           | @tsv' \
  | sed -e 's/\t/  /g'
  # If recursion is requested, do the same in subdirs.
  if $recursive ; then
    get_subdirs "$path" \
    | while read -r subdir ; do
      list_online_files "$path/$subdir" "$recursive"
    done
  fi
}



