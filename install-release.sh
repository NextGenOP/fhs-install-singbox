#!/usr/bin/env bash
# shellcheck disable=SC2268

# The files installed by the script conform to the Filesystem Hierarchy Standard:
# https://wiki.linuxfoundation.org/lsb/fhs

# The URL of the script project is:
# https://github.com/NextGenOP/fhs-install-singbox

# The URL of the script is:
# https://raw.githubusercontent.com/NextGenOP/fhs-install-singbox/master/install-release.sh

# If the script executes incorrectly, go to:
# https://github.com/NextGenOP/fhs-install-singbox/issues

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export DAT_PATH='/usr/local/share/sing-box'
DAT_PATH=${DAT_PATH:-/usr/local/etc/sing-box}

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export JSON_PATH='/usr/local/etc/sing-box'
JSON_PATH=${JSON_PATH:-/usr/local/etc/sing-box}

# Set this variable only if you are starting sing-box with multiple configuration files:
# export JSONS_PATH='/usr/local/etc/sing-box'

# Set this variable only if you want this script to check all the systemd unit file:
# export check_all_service_files='yes'

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}

systemd_cat_config() {
  if systemd-analyze --help | grep -qw 'cat-config'; then
    systemd-analyze --no-pager cat-config "$@"
    echo
  else
    echo "${aoi}~~~~~~~~~~~~~~~~"
    cat "$@" "$1".d/*
    echo "${aoi}~~~~~~~~~~~~~~~~"
    echo "${red}warning: ${green}The systemd version on the current operating system is too low."
    echo "${red}warning: ${green}Please consider to upgrade the systemd or the operating system.${reset}"
    echo
  fi
}

check_if_running_as_root() {
  # If you want to run as another user, please modify $UID to be owned by this user
  if [[ "$UID" -ne '0' ]]; then
    echo "WARNING: The user currently executing this script is not root. You may encounter the insufficient privilege error."
    read -r -p "Are you sure you want to continue? [y/n] " cont_without_been_root
    if [[ x"${cont_without_been_root:0:1}" = x'y' ]]; then
      echo "Continuing the installation with current user..."
    else
      echo "Not running with root, exiting..."
      exit 1
    fi
  fi
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='64'
        ;;
      'armv5tel')
        MACHINE='arm32-v5'
        ;;
      'armv6l')
        MACHINE='arm32-v6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm32-v7a'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
    ### Refer: https://github.com/v2fly/fhs-install-v2ray/issues/84#issuecomment-688574989
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

## Demo function for processing parameters
judgment_parameters() {
  while [[ "$#" -gt '0' ]]; do
    case "$1" in
      '--remove')
        if [[ "$#" -gt '1' ]]; then
          echo 'error: Please enter the correct parameters.'
          exit 1
        fi
        REMOVE='1'
        ;;
      '--version')
        VERSION="${2:?error: Please specify the correct version.}"
        break
        ;;
      '-c' | '--check')
        CHECK='1'
        break
        ;;
      '-f' | '--force')
        FORCE='1'
        break
        ;;
      '-h' | '--help')
        HELP='1'
        break
        ;;
      '-l' | '--local')
        LOCAL_INSTALL='1'
        LOCAL_FILE="${2:?error: Please specify the correct local file.}"
        break
        ;;
      '-p' | '--proxy')
        if [[ -z "${2:?error: Please specify the proxy server address.}" ]]; then
          exit 1
        fi
        PROXY="$2"
        shift
        ;;
      *)
        echo "$0: unknown option -- -"
        exit 1
        ;;
    esac
    shift
  done
}

install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" > /dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name"; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}

get_current_version() {
  if /usr/local/bin/sing-box version > /dev/null 2>&1; then
    VERSION="$(/usr/local/bin/sing-box version | awk 'NR==1 {print $3}')"
  else
    VERSION="$(/usr/local/bin/sing-box -version | awk 'NR==1 {print $3}')"
  fi
  CURRENT_VERSION="v${VERSION#v}"
}

get_version() {
  # 0: Install or update sing-box.
  # 1: Installed or no new version of sing-box.
  # 2: Install the specified version of sing-box.
  if [[ -n "$VERSION" ]]; then
    RELEASE_VERSION="v${VERSION#v}"
    return 2
  fi
  # Determine the version number for sing-box installed from a local file
  if [[ -f '/usr/local/bin/sing-box' ]]; then
    get_current_version
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
      RELEASE_VERSION="$CURRENT_VERSION"
      return
    fi
  fi
  # Get sing-box release version number
  TMP_FILE="$(mktemp)"
  if ! curl -x "${PROXY}" -sS -i -H "Accept: application/vnd.github.v3+json" -o "$TMP_FILE" 'https://api.github.com/repos/SagerNet/sing-box/releases/latest'; then
    "rm" "$TMP_FILE"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
  fi
  HTTP_STATUS_CODE=$(awk 'NR==1 {print $2}' "$TMP_FILE")
  if [[ $HTTP_STATUS_CODE -lt 200 ]] || [[ $HTTP_STATUS_CODE -gt 299 ]]; then
    "rm" "$TMP_FILE"
    echo "error: Failed to get release list, GitHub API response code: $HTTP_STATUS_CODE"
    exit 1
  fi
  RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
  "rm" "$TMP_FILE"
  RELEASE_VERSION="v${RELEASE_LATEST#v}"
  # Compare sing-box version numbers
  if [[ "$RELEASE_VERSION" != "$CURRENT_VERSION" ]]; then
    RELEASE_VERSIONSION_NUMBER="${RELEASE_VERSION#v}"
    RELEASE_MAJOR_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER%%.*}"
    RELEASE_MINOR_VERSION_NUMBER="$(echo "$RELEASE_VERSIONSION_NUMBER" | awk -F '.' '{print $2}')"
    RELEASE_MINIMUM_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER##*.}"
    # shellcheck disable=SC2001
    CURRENT_VERSION_NUMBER="$(echo "${CURRENT_VERSION#v}" | sed 's/-.*//')"
    CURRENT_MAJOR_VERSION_NUMBER="${CURRENT_VERSION_NUMBER%%.*}"
    CURRENT_MINOR_VERSION_NUMBER="$(echo "$CURRENT_VERSION_NUMBER" | awk -F '.' '{print $2}')"
    CURRENT_MINIMUM_VERSION_NUMBER="${CURRENT_VERSION_NUMBER##*.}"
    if [[ "$RELEASE_MAJOR_VERSION_NUMBER" -gt "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
      return 0
    elif [[ "$RELEASE_MAJOR_VERSION_NUMBER" -eq "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
      if [[ "$RELEASE_MINOR_VERSION_NUMBER" -gt "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
        return 0
      elif [[ "$RELEASE_MINOR_VERSION_NUMBER" -eq "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
        if [[ "$RELEASE_MINIMUM_VERSION_NUMBER" -gt "$CURRENT_MINIMUM_VERSION_NUMBER" ]]; then
          return 0
        else
          return 1
        fi
      else
        return 1
      fi
    else
      return 1
    fi
  elif [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
    return 1
  fi
}

download_sing-box() {
  DOWNLOAD_LINK="https://github.com/SagerNet/sing-box/releases/download/$RELEASE_VERSION/$FILE_NAME.tar.gz"
  GEOSITE_LINK="https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db"
  GEOIP_LINK="https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db"
  echo "Downloading sing-box archive: $DOWNLOAD_LINK"
  echo "Downloading geosite: $GEOSITE_LINK"
  echo "Downloading geoip: $GEOIP_LINK"
  if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK" -o "$TMP_DIRECTORY/geoip.db" "$GEOIP_LINK" -o "$TMP_DIRECTORY/geosite.db" "$GEOSITE_LINK"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  
  # echo "Downloading verification file for sing-box archive: $DOWNLOAD_LINK.dgst"
  # if ! curl -x "${PROXY}" -sSR -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
  #   echo 'error: Download failed! Please check your network or try again.'
  #   return 1
  # fi
  # if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
  #   echo 'error: This version does not support verification. Please replace with another version.'
  #   return 1
  # fi

  # Verification of sing-box archive
  # CHECKSUM=$(awk -F '= ' '/256=/ {print $2}' < "${ZIP_FILE}.dgst")
  # LOCALSUM=$(sha256sum "$ZIP_FILE" | awk '{printf $1}')
  # if [[ "$CHECKSUM" != "$LOCALSUM" ]]; then
  #   echo 'error: SHA256 check failed! Please check your network or try again.'
  #   return 1
  # fi
}

decompression() {
  if ! tar -xvf "$1" -C "$TMP_DIRECTORY"; then
    echo 'error: sing-box decompression failed.'
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  echo "info: Extract the sing-box package to $TMP_DIRECTORY and prepare it for installation."
}

install_file() {
  NAME="$1"
  if [[ "$NAME" == 'sing-box' ]]; then
    install -m 755 "${EXTRACTED_DIRECTORY}/$NAME" "/usr/local/bin/$NAME"
  elif [[ "$NAME" == 'geoip.db' ]] || [[ "$NAME" == 'geosite.db' ]]; then
     install -m 644 "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
  fi
}

install_sing-box() {
  # Install sing-box binary to /usr/local/bin/ and $DAT_PATH
  install_file sing-box
  # if [[ -f "${TMP_DIRECTORY}/v2ctl" ]]; then
  #   install_file v2ctl
  # else
  #   if [[ -f '/usr/local/bin/v2ctl' ]]; then
  #     rm '/usr/local/bin/v2ctl'
  #   fi
  # fi
  install -d "$DAT_PATH"
  # If the file exists, geoip.db and geosite.db will not be installed or updated
   if [[ ! -f "${DAT_PATH}/.undat" ]]; then
     install_file geoip.db
     install_file geosite.db
   fi

  # Install sing-box configuration file to $JSON_PATH
  # shellcheck disable=SC2153
  if [[ -z "$JSONS_PATH" ]] && [[ ! -d "$JSON_PATH" ]]; then
    install -d "$JSON_PATH"
    echo "{}" > "${JSON_PATH}/config.json"
    CONFIG_NEW='1'
  fi

  # Install sing-box configuration file to $JSONS_PATH
  # if [[ -n "$JSONS_PATH" ]] && [[ ! -d "$JSONS_PATH" ]]; then
  #   install -d "$JSONS_PATH"
  #    for BASE in 00_log 01_api 02_dns 03_routing 04_policy 05_inbounds 06_outbounds 07_transport 08_stats 09_reverse; do
  #     echo '{}' > "${JSONS_PATH}/${BASE}.json"
  #    done
  #   CONFDIR='1'
  # fi

  # Used to store sing-box log files
  if [[ ! -d '/var/log/sing-box/' ]]; then
    if id nobody | grep -qw 'nogroup'; then
      install -d -m 700 -o nobody -g nogroup /var/log/sing-box/
      install -m 600 -o nobody -g nogroup /dev/null /var/log/sing-box/access.log
      install -m 600 -o nobody -g nogroup /dev/null /var/log/sing-box/error.log
    else
      install -d -m 700 -o nobody -g nobody /var/log/sing-box/
      install -m 600 -o nobody -g nobody /dev/null /var/log/sing-box/access.log
      install -m 600 -o nobody -g nobody /dev/null /var/log/sing-box/error.log
    fi
    LOG='1'
  fi
}

install_startup_service_file() {
  get_current_version
  # if [[ "$(echo "${CURRENT_VERSION#v}" | sed 's/-.*//' | awk -F'.' '{print $1}')" -gt "4" ]]; then
    START_COMMAND="/usr/local/bin/sing-box run"
  # else
  #   START_COMMAND="/usr/local/bin/sing-box"
  # fi
  #install -m 644 "${EXTRACTED_DIRECTORY}/systemd/system/sing-box.service" /etc/systemd/system/sing-box.service
  #install -m 644 "${EXTRACTED_DIRECTORY}/systemd/system/sing-box@.service" /etc/systemd/system/sing-box@.service
  echo '[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target' >/etc/systemd/system/sing-box.service
  echo '[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box-%i -c /etc/sing-box/%i.json run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/sing-box@.service
  echo "info: Systemd service files have been installed successfully!"
  echo "${red}warning: ${green}The following are the actual parameters for the sing-box service startup."
  echo "${red}warning: ${green}Please make sure the configuration file path is correctly set.${reset}"
  systemd_cat_config /etc/systemd/system/sing-box.service
  # shellcheck disable=SC2154
  if [[ x"${check_all_service_files:0:1}" = x'y' ]]; then
    echo
    echo
    systemd_cat_config /etc/systemd/system/sing-box@.service
  fi
  systemctl daemon-reload
  SYSTEMD='1'
}

start_sing-box() {
  if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
    if systemctl start "${sing-box_CUSTOMIZE:-sing-box}"; then
      echo 'info: Start the sing-box service.'
    else
      echo 'error: Failed to start sing-box service.'
      exit 1
    fi
  fi
}

stop_sing-box() {
  sing-box_CUSTOMIZE="$(systemctl list-units | grep 'sing-box@' | awk -F ' ' '{print $1}')"
  if [[ -z "${sing-box_CUSTOMIZE}" ]]; then
    local sing-box_daemon_to_stop='sing-box.service'
  else
    local sing-box_daemon_to_stop="${sing-box_CUSTOMIZE}"
  fi
  if ! systemctl stop "${sing-box_daemon_to_stop}"; then
    echo 'error: Stopping the sing-box service failed.'
    exit 1
  fi
  echo 'info: Stop the sing-box service.'
}

check_update() {
  if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
    get_version
    local get_ver_exit_code=$?
    if [[ "$get_ver_exit_code" -eq '0' ]]; then
      echo "info: Found the latest release of sing-box $RELEASE_VERSION . (Current release: $CURRENT_VERSION)"
    elif [[ "$get_ver_exit_code" -eq '1' ]]; then
      echo "info: No new version. The current version of sing-box is $CURRENT_VERSION ."
    fi
    exit 0
  else
    echo 'error: sing-box is not installed.'
    exit 1
  fi
}

remove_sing-box() {
  if systemctl list-unit-files | grep -qw 'sing-box'; then
    if [[ -n "$(pidof sing-box)" ]]; then
      stop_sing-box
    fi
    if ! ("rm" -r '/usr/local/bin/sing-box' \
      "$DAT_PATH" \
      '/etc/systemd/system/sing-box.service' \
      '/etc/systemd/system/sing-box@.service'); then
      echo 'error: Failed to remove sing-box.'
      exit 1
    else
      echo 'removed: /usr/local/bin/sing-box'
      # if [[ -f '/usr/local/bin/v2ctl' ]]; then
      #   rm '/usr/local/bin/v2ctl'
      #   echo 'removed: /usr/local/bin/v2ctl'
      # fi
      echo "removed: $DAT_PATH"
      echo 'removed: /etc/systemd/system/sing-box.service'
      echo 'removed: /etc/systemd/system/sing-box@.service'
      echo 'Please execute the command: systemctl disable sing-box'
      echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl tar"
      echo 'info: sing-box has been removed.'
      echo 'info: If necessary, manually delete the configuration and log files.'
      if [[ -n "$JSONS_PATH" ]]; then
        echo "info: e.g., $JSONS_PATH and /var/log/sing-box/ ..."
      else
        echo "info: e.g., $JSON_PATH and /var/log/sing-box/ ..."
      fi
      exit 0
    fi
  else
    echo 'error: sing-box is not installed.'
    exit 1
  fi
}

# Explanation of parameters in the script
show_help() {
  echo "usage: $0 [--remove | --version number | -c | -f | -h | -l | -p]"
  echo '  [-p address] [--version number | -c | -f]'
  echo '  --remove        Remove sing-box'
  echo '  --version       Install the specified version of sing-box, e.g., --version v4.18.0'
  echo '  -c, --check     Check if sing-box can be updated'
  echo '  -f, --force     Force installation of the latest version of sing-box'
  echo '  -h, --help      Show help'
  echo '  -l, --local     Install sing-box from a local file'
  echo '  -p, --proxy     Download through a proxy server, e.g., -p http://127.0.0.1:8118 or -p socks5://127.0.0.1:1080'
  exit 0
}

main() {
  check_if_running_as_root
  identify_the_operating_system_and_architecture
  judgment_parameters "$@"

  install_software "$package_provide_tput" 'tput'
  red=$(tput setaf 1)
  green=$(tput setaf 2)
  aoi=$(tput setaf 6)
  reset=$(tput sgr0)

  # Parameter information
  [[ "$HELP" -eq '1' ]] && show_help
  [[ "$CHECK" -eq '1' ]] && check_update
  [[ "$REMOVE" -eq '1' ]] && remove_sing-box

  # Two very important variables
  TMP_DIRECTORY="$(mktemp -d)"

  # Install sing-box from a local file, but still need to make sure the network is available
  if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
    echo 'warn: Install sing-box from a local file, but still need to make sure the network is available.'
    echo -n 'warn: Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
    read -r
    install_software 'tar' 'tar'
    decompression "$LOCAL_FILE"
  else
    # Normal way
    install_software 'curl' 'curl'
    get_version
    FILE_NAME="sing-box-${RELEASE_VERSIONSION_NUMBER}-linux-${MACHINE}"
    ZIP_FILE="${TMP_DIRECTORY}/${FILE_NAME}.tar.gz"
    EXTRACTED_DIRECTORY="$TMP_DIRECTORY/${FILE_NAME}"
    NUMBER="$?"
    if [[ "$NUMBER" -eq '0' ]] || [[ "$FORCE" -eq '1' ]] || [[ "$NUMBER" -eq 2 ]]; then
      echo "info: Installing sing-box $RELEASE_VERSION for $(uname -m)"
      download_sing-box
      if [[ "$?" -eq '1' ]]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
      fi
      install_software 'tar' 'tar'
      decompression "$ZIP_FILE"
    elif [[ "$NUMBER" -eq '1' ]]; then
      echo "info: No new version. The current version of sing-box is $CURRENT_VERSION ."
      exit 0
    fi
  fi

  # Determine if sing-box is running
  if systemctl list-unit-files | grep -qw 'sing-box'; then
    if [[ -n "$(pidof sing-box)" ]]; then
      stop_sing-box
      sing-box_RUNNING='1'
    fi
  fi
  install_sing-box
  install_startup_service_file
  echo 'installed: /usr/local/bin/sing-box'
  if [[ -f '/usr/local/bin/v2ctl' ]]; then
    echo 'installed: /usr/local/bin/v2ctl'
  fi
  # If the file exists, the content output of installing or updating geoip.dat and geosite.dat will not be displayed
  if [[ ! -f "${DAT_PATH}/.undat" ]]; then
    echo "installed: ${DAT_PATH}/geoip.dat"
    echo "installed: ${DAT_PATH}/geosite.dat"
  fi
  if [[ "$CONFIG_NEW" -eq '1' ]]; then
    echo "installed: ${JSON_PATH}/config.json"
  fi
  if [[ "$CONFDIR" -eq '1' ]]; then
    echo "installed: ${JSON_PATH}/00_log.json"
    echo "installed: ${JSON_PATH}/01_api.json"
    echo "installed: ${JSON_PATH}/02_dns.json"
    echo "installed: ${JSON_PATH}/03_routing.json"
    echo "installed: ${JSON_PATH}/04_policy.json"
    echo "installed: ${JSON_PATH}/05_inbounds.json"
    echo "installed: ${JSON_PATH}/06_outbounds.json"
    echo "installed: ${JSON_PATH}/07_transport.json"
    echo "installed: ${JSON_PATH}/08_stats.json"
    echo "installed: ${JSON_PATH}/09_reverse.json"
  fi
  if [[ "$LOG" -eq '1' ]]; then
    echo 'installed: /var/log/sing-box/'
    echo 'installed: /var/log/sing-box/access.log'
    echo 'installed: /var/log/sing-box/error.log'
  fi
  if [[ "$SYSTEMD" -eq '1' ]]; then
    echo 'installed: /etc/systemd/system/sing-box.service'
    echo 'installed: /etc/systemd/system/sing-box@.service'
  fi
  "rm" -r "$TMP_DIRECTORY"
  echo "removed: $TMP_DIRECTORY"
  if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
    get_version
  fi
  echo "info: sing-box $RELEASE_VERSION is installed."
  echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl tar"
  if [[ "${sing-box_RUNNING}" -eq '1' ]]; then
    start_sing-box
  else
    echo 'Please execute the command: systemctl enable sing-box; systemctl start sing-box'
  fi
}

main "$@"
