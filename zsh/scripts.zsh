#!/usr/bin/env zsh

# =============================================================================
# Archive & compression utilities
# =============================================================================

screenres() {
    [ ! -z $1 ] && xrandr --current | grep '*' | awk '{print $1}' | sed -n "$1p"
}

# Extract files
extract() {
    for file in "$@"
    do
        if [ -f $file ]; then
            _ex $file
        else
            echo "'$file' is not a valid file"
        fi
    done
}

# Extract files in their own directories
mkextract() {
    for file in "$@"
    do
        if [ -f $file ]; then
            local filename=${file%\.*}
            mkdir -p $filename
            cp $file $filename
            cd $filename
            _ex $file
            rm -f $file
            cd -
        else
            echo "'$1' is not a valid file"
        fi
    done
}


# Internal function to extract any archive
_ex() {
    case $1 in
        *.tar.bz2)  tar xjf $1      ;;
        *.tar.gz)   tar xzf $1      ;;
        *.bz2)      bunzip2 $1      ;;
        *.gz)       gunzip $1       ;;
        *.tar)      tar xf $1       ;;
        *.tbz2)     tar xjf $1      ;;
        *.tgz)      tar xzf $1      ;;
        *.zip)      unzip $1        ;;
        *.7z)       7z x $1         ;; # require p7zip
        *.rar)      7z x $1         ;; # require p7zip
        *.iso)      7z x $1         ;; # require p7zip
        *.Z)        uncompress $1   ;;
        *)          echo "'$1' cannot be extracted" ;;
    esac
}

# Compress a file
# TODO to improve to compress in any possible format
# TODO to improve to compress multiple files
compress() {
    local DATE="$(date +%Y%m%d-%H%M%S)"
    tar cvzf "$DATE.tar.gz" "$@"
}

# media download helpers
# Policy: keep tracked downloader config generic and credential-free.
# Private site-specific overrides belong in local, untracked config files.
_ytdlp_browser() {
  printf '%s' "${YTDLP_BROWSER:-chromium}"
}

_ytdlp_media_root() {
  printf '%s' "${YTDLP_MEDIA_DIR:-$HOME/media/external}"
}

_gallerydl_config_path() {
  local config_path="$HOME/.dotfiles/.config/gallery-dl/config.json"
  if [[ -f "$config_path" ]]; then
    printf '%s' "$config_path"
    return 0
  fi

  printf '%s' "$HOME/.config/gallery-dl/config.json"
}

_gallerydl_local_config_path() {
  local config_path="$HOME/.dotfiles/.config/gallery-dl/config.local.json"
  if [[ -f "$config_path" ]]; then
    printf '%s' "$config_path"
    return 0
  fi

  printf '%s' "$HOME/.config/gallery-dl/config.local.json"
}

_gallerydl_base_args() {
  reply=(
    --config-ignore
    --config
    "$(_gallerydl_config_path)"
  )

  local local_config
  local_config="$(_gallerydl_local_config_path)"
  [[ -f "$local_config" ]] && reply+=(--config "$local_config")
}

_ytdlp_name_args() {
  reply=(
    --trim-filenames 160
    --replace-in-metadata title "[\"']" ""
    --replace-in-metadata uploader "[\"']" ""
    --replace-in-metadata channel "[\"']" ""
    --replace-in-metadata playlist_title "[\"']" ""
  )
}

_ytdlp_read_url() {
  local url="$1"
  local prompt="$2"

  if [[ -n "$url" ]]; then
    printf '%s' "$url"
    return 0
  fi

  if [[ ! -r /dev/tty ]]; then
    return 1
  fi

  printf '%s' "$prompt" > /dev/tty
  read -r url < /dev/tty
  [[ -n "$url" ]] || return 1

  printf '%s' "$url"
}

_mediadl_pick_mode() {
  if command -v fzf >/dev/null 2>&1; then
    local selection
    selection="$({
      printf 'video\tUse yt-dlp for a single video or video-first URL\n'
      printf 'playlist\tUse yt-dlp for playlists or channel-style URLs\n'
      printf 'audio\tUse yt-dlp and extract audio as MP3\n'
      printf 'instagram\tUse gallery-dl with Instagram-specific paths\n'
      printf 'social\tUse gallery-dl for Reddit, X, Bluesky, and similar\n'
      printf 'archive\tUse yt-dlp archive mode with download history and logs\n'
    } | fzf \
      --delimiter=$'\t' \
      --with-nth=1,2 \
      --prompt="media > " \
      --height=16 \
      --border \
      --header="Pick a download mode" \
      --preview='printf "%s\n\n%s\n" {1} {2}' \
      --preview-window='down:3:wrap')" || return 1

    printf '%s' "${selection%%$'\t'*}"
    return
  fi

  printf 'video'
}

_mediadl_read_url() {
  _ytdlp_read_url "$1" "Media URL: "
}

_mediadl_mode_for_url() {
  local url="$1"

  case "$url" in
    *instagram.com/*)
      printf '%s' "instagram"
      ;;
    *reddit.com/*|*redd.it/*|*x.com/*|*twitter.com/*|*bsky.app/*|*bluesky.app/*|*pinterest.com/*|*pin.it/*)
      printf '%s' "social"
      ;;
    *) printf '%s' "video" ;;
  esac
}

_mediadl_help() {
  cat <<'EOF'
mediadl - download media with the right backend

Usage:
  mediadl <url> [extra args...]
  mediadl [--yt|--playlist|--audio|--social|--instagram|--archive] <url> [extra args...]
  mediadl

Default behavior:
  - Detects the backend from the URL
  - Uses gallery-dl for Instagram, Pinterest, Reddit, X/Twitter, and Bluesky
  - Uses yt-dlp for video-first URLs
  - Keeps Instagram downloads on the dedicated `~/media/external/instagram` path

Overrides:
  --yt, --video     Force yt-dlp single-video mode
  --playlist        Force yt-dlp playlist mode
  --audio           Force yt-dlp audio extract mode
  --social          Force gallery-dl generic social/gallery mode
  --instagram       Force gallery-dl Instagram mode
  --archive         Force yt-dlp archive mode

Examples:
  mediadl "https://www.instagram.com/p/..."
  mediadl "https://www.youtube.com/watch?v=..."
  mediadl --audio "https://www.youtube.com/watch?v=..."
  mediadl --social "https://x.com/..."

Shortcuts:
  ytdl      Alias for mediadl
  igdl      Force gallery-dl Instagram flow
  gdl       Force gallery-dl generic flow
  ytdlaudio Force yt-dlp audio flow
EOF
}

_mediadl_announce() {
  local backend="$1"
  local mode="$2"

  if [[ -t 1 ]]; then
    printf 'Using %s for %s\n' "$backend" "$mode"
  fi
}

mediadl() {
  local mode=""
  local url=""

  case "$1" in
    -h|--help|help)
      _mediadl_help
      return 0
      ;;
    --yt|--video) mode="video" ; shift ;;
    --playlist) mode="playlist" ; shift ;;
    --audio) mode="audio" ; shift ;;
    --gallery|--social) mode="social" ; shift ;;
    --ig|--instagram) mode="instagram" ; shift ;;
    --archive) mode="archive" ; shift ;;
  esac

  if [[ -n "$mode" ]]; then
    if [[ "$1" == http://* || "$1" == https://* ]]; then
      url="$1"
      shift
    fi
  else
      case "$1" in
      video|playlist|audio|instagram|gallery|social|archive)
        mode="$1"
        shift
        ;;
      "")
        mode="$(_mediadl_pick_mode)" || return 1
        [[ -n "$mode" ]] || { echo "Cancelled."; return 1; }
        url="$(_mediadl_read_url "$1")" || {
          echo "Usage: mediadl <url> [extra args...]"
          return 1
        }
        ;;
      http://*|https://*)
        url="$1"
        mode="$(_mediadl_mode_for_url "$url")"
        shift
        ;;
      *)
        echo "Unknown mode or URL: $1"
        echo "Run 'mediadl --help' for usage."
        return 1
        ;;
    esac
  fi

  [[ -n "$url" ]] && set -- "$url" "$@"

  case "$mode" in
    video)
      _mediadl_announce "yt-dlp" "video"
      ytdlvideo "$@"
      ;;
    playlist)
      _mediadl_announce "yt-dlp" "playlist"
      ytdlplaylist "$@"
      ;;
    audio)
      _mediadl_announce "yt-dlp" "audio"
      ytdlaudio "$@"
      ;;
    instagram)
      _mediadl_announce "gallery-dl" "instagram"
      igdl "$@"
      ;;
    gallery|social)
      _mediadl_announce "gallery-dl" "social"
      gdl "$@"
      ;;
    archive)
      _mediadl_announce "yt-dlp" "archive"
      ytdlarchive "$@"
      ;;
  esac
}

ytdl() {
  if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" ]]; then
    _mediadl_help
    return 0
  fi

  mediadl "$@"
}

ytdlplaylist() {
  local url
  url="$(_ytdlp_read_url "$1" "Playlist URL: ")" || {
    echo "Usage: ytdlplaylist <playlist-URL> [extra yt-dlp args...]"
    return 1
  }
  (( $# > 0 )) && shift

  local browser="$(_ytdlp_browser)"
  local media_root="$(_ytdlp_media_root)"
  local -a name_args
  _ytdlp_name_args
  name_args=("${reply[@]}")

  yt-dlp \
    --cookies-from-browser "$browser" \
    --yes-playlist \
    -f "bv*+ba/b" \
    --merge-output-format mkv \
    "${name_args[@]}" \
    -o "${media_root}/ytdlp/playlists/%(uploader)s/%(playlist_title)s/%(playlist_index)03d - %(title)s [%(id)s].%(ext)s" \
    "$@" \
    -- "$url"
}

ytdlvideo() {
  local url
  url="$(_ytdlp_read_url "$1" "Video URL: ")" || {
    echo "Usage: ytdlvideo <video-URL> [extra yt-dlp args...]"
    return 1
  }
  (( $# > 0 )) && shift

  local browser="$(_ytdlp_browser)"
  local media_root="$(_ytdlp_media_root)"
  local -a name_args
  _ytdlp_name_args
  name_args=("${reply[@]}")

  yt-dlp \
    --cookies-from-browser "$browser" \
    --no-playlist \
    -f "bv*+ba/b" \
    --merge-output-format mkv \
    "${name_args[@]}" \
    -o "${media_root}/ytdlp/video/%(uploader)s/%(upload_date)s-%(title)s [%(id)s].%(ext)s" \
    "$@" \
    -- "$url"
}

ytdlaudio() {
  local url
  url="$(_ytdlp_read_url "$1" "Audio URL: ")" || {
    echo "Usage: ytdlaudio <video-URL> [extra yt-dlp args...]"
    return 1
  }
  (( $# > 0 )) && shift

  local browser="$(_ytdlp_browser)"
  local media_root="$(_ytdlp_media_root)"
  local -a name_args
  _ytdlp_name_args
  name_args=("${reply[@]}")

  yt-dlp \
    --cookies-from-browser "$browser" \
    --no-playlist \
    -f bestaudio \
    --extract-audio --audio-format mp3 --audio-quality 0 \
    "${name_args[@]}" \
    -o "${media_root}/music/%(uploader)s/%(uploader)s - %(title)s [%(id)s].%(ext)s" \
    "$@" \
    -- "$url"
}

_gallerydl_run() {
  local label="$1"
  shift

  local url
  url="$(_ytdlp_read_url "$1" "$label URL: ")" || {
    echo "Usage: gallery helper <url> [extra gallery-dl args...]"
    return 1
  }
  (( $# > 0 )) && shift

  local -a config_args
  _gallerydl_base_args
  config_args=("${reply[@]}")

  gallery-dl \
    "${config_args[@]}" \
    "$@" \
    "$url"
}

igdl() {
  _gallerydl_run "Instagram" "$@"
}

gdl() {
  _gallerydl_run "Gallery" "$@"
}

_webmirror_check_robots() {
  local url="$1"
  local host="${url#*://}"
  host="${host%%/*}"
  host="${host%%:*}"

  local scheme="https"
  [[ "$url" == http://* ]] && scheme="http"
  local robots_url="${scheme}://${host}/robots.txt"

  echo "Checking robots.txt: $robots_url"

  local robots
  robots="$(curl -fsSL --connect-timeout 5 --max-time 10 "$robots_url" 2>/dev/null || true)"

  if [ -z "$robots" ]; then
    echo "Warning: Could not fetch robots.txt. Proceeding carefully."
    return 0
  fi

  local rules
  rules="$(printf "%s\n" "$robots" | awk '
    BEGIN { in_star=0 }
    /^[[:space:]]*#/ { next }
    {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      lower=tolower(line)

      if (lower ~ /^user-agent:[[:space:]]*/) {
        sub(/^user-agent:[[:space:]]*/, "", lower)
        in_star=(lower=="*")
        next
      }

      if (in_star && lower ~ /^disallow:[[:space:]]*\/$/) {
        print "disallow_all"
      }

      if (in_star && lower ~ /^crawl-delay:[[:space:]]*[0-9]+/) {
        sub(/^crawl-delay:[[:space:]]*/, "", lower)
        print "crawl_delay=" lower
      }
    }
  ' | sort -u)"

  if printf "%s\n" "$rules" | grep -q '^crawl_delay='; then
    local delay
    delay="$(printf "%s\n" "$rules" | awk -F= '/^crawl_delay=/{print $2; exit}')"
    if [ -n "$delay" ]; then
      echo "Notice: robots.txt requests crawl-delay=$delay for User-agent: *."
      echo "Consider increasing wait/rate limits with extra args."
    fi
  fi

  if printf "%s\n" "$rules" | grep -q '^disallow_all$'; then
    echo "Concern: robots.txt for $host contains 'User-agent: *' + 'Disallow: /'."
    echo "This site indicates scraping is not allowed. Aborting."
    return 1
  fi

  return 0
}

# Mirror a site with polite wget defaults
webmirror() {
  if [ -z "$1" ]; then
    echo "Usage: webmirror <url> [output-dir] [extra wget args...]"
    return 1
  fi

  local url="$1"
  shift

  local host
  host="${url#*://}"
  host="${host%%/*}"
  host="${host%%:*}"

  local outdir=""
  if [ -n "$1" ] && [[ "$1" != -* ]]; then
    outdir="$1"
    shift
  fi

  if [ -z "$outdir" ]; then
    outdir="$HOME/Downloads/$host"
  fi

  _webmirror_check_robots "$url" || return 1

  local args=(
    --mirror
    --convert-links
    --adjust-extension
    --page-requisites
    --no-parent
    --wait=1
    --random-wait
    --limit-rate=1m
    --reject "index.html?*"
  )

  if [ -n "$outdir" ]; then
    args+=(--directory-prefix "$outdir")
  fi

  wget "${args[@]}" "$@" -- "$url"
}

# Mirror difficult sites with httrack defaults
webmirror-deep() {
  if [ -z "$1" ]; then
    echo "Usage: webmirror-deep <url> [output-dir] [extra httrack args...]"
    return 1
  fi

  local url="$1"
  shift

  local outdir=""
  if [ -n "$1" ] && [[ "$1" != -* ]]; then
    outdir="$1"
    shift
  fi

  local host
  host="${url#*://}"
  host="${host%%/*}"
  host="${host%%:*}"

  if [ -z "$outdir" ]; then
    outdir="$HOME/Downloads/$host"
  fi

  _webmirror_check_robots "$url" || return 1

  httrack "$url" -O "$outdir" "+*.${host}/*" \
    --sockets=2 --connection-per-second=1 -%v "$@"
}

# Default: progress + warnings (no debug spam)
# Add --debug anywhere after the URL to turn on full verbose for that run
ytdlarchive() {
  local url
  url="$(_ytdlp_read_url "$1" "Archive URL: ")" || {
    echo "Usage: ytdlarchive <channel-or-playlist-URL> [extra yt-dlp args... | --debug]"
    return 1
  }
  (( $# > 0 )) && shift

  local browser="$(_ytdlp_browser)"
  local media_root="$(_ytdlp_media_root)"
  local -a verbosity_args=()

  # Peek for an optional --debug flag in user args
  local debug=0
  for arg in "$@"; do
    [[ "$arg" = "--debug" ]] && debug=1
  done
  # Strip our --debug from the args passed to yt-dlp
  # (safe even if it's not present)
  local -a passthrough_args=()
  for arg in "$@"; do
    [[ "$arg" = "--debug" ]] || passthrough_args+=("$arg")
  done
  (( debug )) && verbosity_args=(--verbose)

  # Resolve uploader id
  local uploader_id
  uploader_id="$(yt-dlp --cookies-from-browser "$browser" --print "%(uploader_id|uploader)s" -- "$url" | head -n1)" || return 2
  [[ -z "$uploader_id" ]] && { echo "Could not resolve uploader id."; return 2; }

  # Paths
  local archive_root="${media_root}/.media-archives/yt-dlp"
  local base="${archive_root}/${uploader_id}"
  local arch="${base}.txt"
  local alllog="${base}.log"
  local runlog="${base}.run.$(date +%Y%m%d-%H%M%S).log"
  local faillog="${base}.failures.log"
  local errraw="${base}.errors.raw.log"

  mkdir -p "$archive_root"
  [[ -e "$faillog" ]] || : > "$faillog"
  [[ -e "$errraw" ]]  || : > "$errraw"

  echo "[ytdlarchive] URL: $url"
  echo "[ytdlarchive] Uploader: $uploader_id"
  echo "[ytdlarchive] Archive: $arch"
  echo "[ytdlarchive] Logs: $runlog (and $alllog)"

  # Build common flags: keep progress even through pipes, print each update on a new line
  # (no --verbose by default; add it only if --debug was requested)
  PYTHONUNBUFFERED=1 yt-dlp \
    --cookies-from-browser "$browser" \
    "${passthrough_args[@]}" \
    --download-archive "$arch" \
    --progress --newline \
    "${verbosity_args[@]}" \
    -- "$url" 2>&1 | tee -a "$alllog" "$runlog"

  local code=${PIPESTATUS[0]:-${pipestatus[1]}}

  # Best-effort retry list from this run
  grep -oE '\[youtube\] [A-Za-z0-9_-]{11}' "$runlog" \
    | awk '{print "https://www.youtube.com/watch?v="$2}' \
    | sort -u >> "$faillog"
  grep -E '^ERROR:' "$runlog" >> "$errraw"

  echo "[ytdlarchive] Failures (retry list): $faillog"
  return "$code"
}

# Pull cheatsheet from cheat.sh
cheat() {
    curl cheat.sh/$1
}
