#!/usr/bin/env bash
# shellcheck disable=SC2268

# This Bash script to install the latest release of geoip.dat and geosite.dat:

# https://github.com/SagerNet/sing-geoip
# https://github.com/SagerNet/sing-geosite

# Depends on cURL, please solve it yourself

# You may plan to execute this Bash script regularly:

# install -m 755 install-dat-release.sh /usr/local/bin/install-dat-release

# 0 0 * * * /usr/local/bin/install-dat-release > /dev/null 2>&1

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export DAT_PATH='/usr/local/lib/sing-box'
DAT_PATH=${DAT_PATH:-/usr/local/sing-box}

DOWNLOAD_LINK_GEOIP="https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db"
DOWNLOAD_LINK_GEOSITE="https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db"
file_ip='geoip.db'
file_dlc='dlc.dat'
file_site='geosite.db'
dir_tmp="$(mktemp -d)"

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
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

download_files() {
  if ! curl -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}" "${1}"; then
    echo 'error: Download failed! Please check your network or try again.'
    exit 1
  fi
  # if ! curl -R -H 'Cache-Control: no-cache' -o "${dir_tmp}/${2}.sha256sum" "${1}.sha256sum"; then
  #   echo 'error: Download failed! Please check your network or try again.'
  #   exit 1
  # fi
}

# check_sum() {
#   (
#     cd "${dir_tmp}" || exit
#     for i in "${dir_tmp}"/*.sha256sum; do
#       if ! sha256sum -c "${i}"; then
#         echo 'error: Check failed! Please check your network or try again.'
#         exit 1
#       fi
#     done
#   )
# }

install_file() {
  install -m 644 "${dir_tmp}"/${file_site} "${DAT_PATH}"/${file_site}
  install -m 644 "${dir_tmp}"/${file_ip} "${DAT_PATH}"/${file_ip}
  rm -r "${dir_tmp}"
}

main() {
  check_if_running_as_root
  download_files $DOWNLOAD_LINK_GEOIP $file_ip
  download_files $DOWNLOAD_LINK_GEOSITE $file_site
  check_sum
  install_file
}

main "$@"
