#!/usr/bin/env bash
#
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
have_real=$(type -p realpath)
[ "${have_real}" ] && SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"

arch=$(uname -m)
[ "${arch}" == "arm64" ] || arch="amd64"
platform=$(uname -s)
plat="linux"
[ "${platform}" == "Darwin" ] && plat="darwin"
have_brew=$(type -p brew)

install_obsidian_release() {
  API_URL="https://api.github.com/repos/${OWNER}/${PROJECT}/releases/latest"
  if [ "${plat}" == "darwin" ]; then
    suff="dmg"
  else
    suff="deb"
  fi
  DL_URL=
  DL_URL=$(curl --silent ${AUTH_HEADER} "${API_URL}" \
    | jq --raw-output '.assets | .[]?.browser_download_url' \
    | grep "\.${suff}$")

  [ "${DL_URL}" ] && {
    printf "\nInstalling %s\n" "${PROJECT}"
    TEMP_PKG="/tmp/obsidian$$.${suff}"
    wget --quiet -O "${TEMP_PKG}" "${DL_URL}"
    chmod 644 "${TEMP_PKG}"
    if [ "${plat}" == "darwin" ]; then
      have_mount=$(type -p hdiutil)
      [ "${have_mount}" ] && {
        [ -d "$HOME"/Applications ] || mkdir -p "$HOME"/Applications
        sudo hdiutil attach "${TEMP_PKG}"
        volname=$(ls -d /Volumes/Obsidian*universal)
        [ -d "${volname}" ] && {
          [ -d "$HOME"/Applications/Obsidian.app ] && {
            rm -rf "$HOME"/Applications/Obsidian.app
          }
          cp -a "${volname}"/Obsidian.app "$HOME"/Applications
          sudo hdiutil detach "${volname}"
        }
      }
    else
      have_apt=$(type -p apt)
      [ "${have_apt}" ] && sudo apt install -y "${TEMP_PKG}"
    fi
    rm -f "${TEMP_PKG}"
  }
}

install_glow() {
  API_URL="https://api.github.com/repos/${OWNER}/${PROJECT}/releases/latest"
  if [ "${plat}" == "darwin" ]; then
    suff="Darwin"
  else
    suff="Linux"
  fi
  if [ "${arch}" == "arm64" ]; then
    glow_arch="arm64"
  else
    glow_arch="x86_64"
  fi
  DL_URL=
  DL_URL=$(curl --silent ${AUTH_HEADER} "${API_URL}" \
    | jq --raw-output '.assets | .[]?.browser_download_url' \
    | grep "_${suff}_${glow_arch}.tar.gz$")

  printf "\nInstalling %s\n" "${PROJECT}"
  if [ "${DL_URL}" ]; then
    TEMP_TGZ="/tmp/glow$$.tgz"
    wget --quiet -O "${TEMP_TGZ}" "${DL_URL}"
    chmod 644 "${TEMP_TGZ}"
    mkdir /tmp/glow$$
    tar -C /tmp/glow$$ -xzf "${TEMP_TGZ}"
    [ -f /tmp/glow$$/glow ] && {
      [ -d "${HOME}"/.local/bin ] || mkdir -p "${HOME}"/.local/bin
      cp /tmp/glow$$/glow "${HOME}"/.local/bin/glow
      chmod 755 "${HOME}"/.local/bin/glow
    }
    rm -f "${TEMP_TGZ}"
    rm -rf /tmp/glow$$
  else
    [ "${have_brew}" ] && brew install glow >/dev/null 2>&1
    have_glow=$(type -p glow)
    [ "${have_glow}" ] || {
      [ -x /usr/local/go/bin/go ] && {
        /usr/local/go/bin/go install github.com/charmbracelet/glow@latest
      }
    }
  fi
}

install_go() {
  go_version="1.22.1"
  [ -d /usr/local ] || sudo mkdir -p /usr/local
  if [ "${plat}" == "darwin" ]; then
    curl --silent --location --output /tmp/go$$.pkg \
         https://go.dev/dl/go${go_version}.darwin-${arch}.pkg
    sudo installer -pkg /tmp/go$$.pkg -target /
    rm -f /tmp/go$$.pkg
  else
    if [ "${arch}" == "arm64" ]; then
      printf "\nARM architechture Go install not supported.\n"
    else
      curl --silent --location --output /tmp/go$$.tgz \
           https://go.dev/dl/go${go_version}.linux-amd64.tar.gz
      sudo tar -C /usr/local -xf /tmp/go$$.tgz
      rm -f /tmp/go$$.tgz
    fi
  fi
}

install_obs() {
  API_URL="https://api.github.com/repos/Yakitrak/obsidian-cli/releases/latest"
  DL_URL=
  DL_URL=$(curl --silent ${AUTH_HEADER} "${API_URL}" \
    | jq --raw-output '.assets | .[]?.browser_download_url' \
    | grep "obsidian-cli" | grep "${plat}_${arch}\.tar\.gz")

  [ "${DL_URL}" ] && {
    printf "\nInstalling OBS ..."
    TEMP_TGZ="/tmp/obs$$.tgz"
    wget --quiet -O "${TEMP_TGZ}" "${DL_URL}"
    chmod 644 "${TEMP_TGZ}"
    [ -d /usr/local ] || sudo mkdir -p /usr/local
    [ -d /usr/local/bin ] || sudo mkdir -p /usr/local/bin
    sudo tar -C /usr/local/bin -xf "${TEMP_TGZ}"
    sudo rm -f "${TEMP_TGZ}" /usr/local/bin/LICENSE /usr/local/bin/README.md
    # We run through hoops because the maintainer has not changed the name of
    # the command even though it conflicts with OBS Studio but he might do so.
    # We need it to be 'obs-cli'
    if [ -f /usr/local/bin/obs ]; then
      sudo mv /usr/local/bin/obs /usr/local/bin/obs-cli
      sudo chmod 755 /usr/local/bin/obs-cli
    else
      if [ -f /usr/local/bin/obs-cli ]; then
        sudo chmod 755 /usr/local/bin/obs-cli
      else
        for cli in /usr/local/bin/obs*
        do
          [ "${cli}" == "/usr/local/bin/obs*" ] && continue
          sudo ln -s "${cli}" /usr/local/bin/obs-cli
          break
        done
      fi
    fi
    printf " done"
  }
}

install_ranger() {
  if [ "${have_brew}" ]; then
    brew install ranger >/dev/null 2>&1
  else
    have_make=$(type -p make)
    if [ "${have_make}" ]; then
      printf "\nInstalling ranger\n"
      HERE=$(pwd)
      git clone https://github.com/ranger/ranger /tmp/ranger$$ >/dev/null 2>&1
      cd /tmp/ranger$$
      git checkout stable >/dev/null 2>&1
      ${SUDO} make install >/dev/null 2>&1
      cd "${HERE}"
      ${SUDO} rm -rf /tmp/ranger$$
    else
      printf "\nInstallation of ranger requires 'make' or Homebrew."
      printf "\nInstall 'make/Homebrew' or install ranger using the native package manager."
      printf "\nSkipping installation of ranger.\n"
    fi
  fi
}

if [ -d ${HOME}/bin ]; then
  cp ${SCRIPT_PATH}/bin/* ${HOME}/bin
else
  cp -a ${SCRIPT_PATH}/bin ${HOME}/bin
fi

have_ranger=$(type -p ranger)
[ "${have_ranger}" ] || install_ranger

[ -d ${HOME}/.config/ranger ] || mkdir -p ${HOME}/.config/ranger
for rfc in commands_full.py commands.py rc.conf rifle.conf scope.sh
do
  [ -f ${HOME}/.config/ranger/${rfc} ] && {
    diff ${SCRIPT_PATH}/${rfc} ${HOME}/.config/ranger/${rfc} > /dev/null || {
      printf "\nBacking up ${HOME}/.config/ranger/${rfc} as ${HOME}/.config/ranger/${rfc}.bak\n"
      cp ${HOME}/.config/ranger/${rfc} ${HOME}/.config/ranger/${rfc}.bak
    }
  }
  cp ${SCRIPT_PATH}/${rfc} ${HOME}/.config/ranger/${rfc}
done
chmod 755 ${HOME}/.config/ranger/*.sh
if [ -d ${HOME}/.config/ranger/plugins ]; then
  for plug in zoxide ranger-fzf-filter ranger_devicons
  do
    if [ -d ${HOME}/.config/ranger/plugins/${plug} ]; then
      cp ${SCRIPT_PATH}/plugins/${plug}/* ${HOME}/.config/ranger/plugins/${plug}
    else
      cp -a ${SCRIPT_PATH}/plugins/${plug} ${HOME}/.config/ranger/plugins
    fi
  done
else
  cp -a ${SCRIPT_PATH}/plugins ${HOME}/.config/ranger
fi

cd ${SCRIPT_PATH}
find share -type f | while read i
do
  [ -f ${HOME}/.local/$i ] || {
    j=$(dirname $i)
    [ -d ${HOME}/.local/$j ] || mkdir -p ${HOME}/.local/$j
    cp $i ${HOME}/.local/$j
  }
done

# GH_TOKEN, a GitHub token must be set in the environment
# If it is not already set then the convenience build script will set it
if [ "${GH_TOKEN}" ]; then
  export GH_TOKEN="${GH_TOKEN}"
else
  export GH_TOKEN="__GITHUB_API_TOKEN__"
fi
# Check to make sure
echo "${GH_TOKEN}" | grep __GITHUB_API | grep __TOKEN__ > /dev/null && {
  # It didn't get set right, unset it
  export GH_TOKEN=
}

if [ "${GH_TOKEN}" ]; then
  AUTH_HEADER="-H \"Authorization: Bearer ${GH_TOKEN}\""
else
  AUTH_HEADER=
fi

install_go
install_obs

OWNER=obsidianmd
PROJECT=obsidian-releases
install_obsidian_release

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

OWNER=charmbracelet
PROJECT=glow
install_glow

if [ -d ${HOME}/Documents/cheat-sheets-plus ]; then
  [ -d ${HOME}/Documents/cheat-sheets-plus/.git ] && {
    git -C ${HOME}/Documents/cheat-sheets-plus pull
  }
else
  git clone https://github.com/doctorfree/cheat-sheets-plus ${HOME}/Documents/cheat-sheets-plus
fi
have_mime=$(type -p xdg-mime)
[ "${have_mime}" ] && xdg-mime default obsidian.desktop x-scheme-handler/obsidian
[ -x /usr/local/bin/obs-cli ] && {
  /usr/local/bin/obs-cli set-default cheat-sheets-plus
}
