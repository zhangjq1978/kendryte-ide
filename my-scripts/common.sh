#!/usr/bin/env bash

export ARCH="x64"

export npm_config_arch="$ARCH"
export PRODUCT_NAME="KendryteIDE"

if [ -z "${VSCODE_ROOT}" ]; then
	export VSCODE_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
fi

if [ -z "${RELEASE_ROOT}" ]; then
	export RELEASE_ROOT="${VSCODE_ROOT}/.release"
	export ARCH_RELEASE_ROOT="${VSCODE_ROOT}/.release/kendryte-ide-release-${ARCH}"
fi

if [ -z "${REAL_HOME}" ]; then
	export REAL_HOME="${HOME}"
	export HOME="${RELEASE_ROOT}/FAKE_HOME"
fi

if [ -z "${TOOLCHAIN_BIN}" ]; then
	export TOOLCHAIN_BIN="${VSCODE_ROOT}/packages/toolchain/bin"
fi

if [ -n "${HTTP_PROXY}${http_proxy}" ]; then
	export HTTP_PROXY="${HTTP_PROXY-"${http_proxy}"}"
	export HTTPS_PROXY="${HTTP_PROXY}" http_proxy="${HTTP_PROXY}" https_proxy="${HTTP_PROXY}"
fi

export SYSTEM=
export FOUND_CYGWIN=
detect_system
if [ -z "${FOUND_CYGWIN}" ] || [ -z "${NODEJS}" ] ; then
	export FOUND_CYGWIN=$(find /bin -name 'cygwin*.dll')
	export NODEJS_INSTALL="${HOME}/nodejs/${ARCH}"
	if [ "${SYSTEM}" = "windows" ]; then
		export NODEJS="${NODEJS_INSTALL}/node.exe"
		export NODEJS_BIN="${NODEJS_INSTALL}"
	else
		export NODEJS="${NODEJS_INSTALL}/bin/node"
		export NODEJS_BIN="${NODEJS_INSTALL}/bin"
	fi
fi

export YARN_CACHE_FOLDER="${RELEASE_ROOT}/yarn-cache"
if [ "$SYSTEM" = "windows" ]; then
	export YARN_CACHE_FOLDER="$(cygpath -m "${YARN_CACHE_FOLDER}")"
fi

if [ -n "${ORIGINAL_PATH}" ]; then
	export ORIGINAL_PATH="$PATH"
fi

if [ "$SYSTEM" = "mac" ]; then
	MAC_LOCAL='/usr/local/bin:' # brew default
fi

export TMP="${RELEASE_ROOT}/tmp"
export TEMP="${TMP}"

mkdir -p "${RELEASE_ROOT}/bin"

export PATH="${RELEASE_ROOT}/bin:./node_modules/.bin:${TOOLCHAIN_BIN}:${NODEJS_BIN}:${MAC_LOCAL}/bin:/usr/bin:/usr/sbin"
if [ "$SYSTEM" = "windows" ]; then
	WinPath=''
	function pushP(){
		if echo "$1" | grep -qE '^/cygdrive/' ; then
			WinPath+="$1:"
		fi
	}
	path_foreach "${ORIGINAL_PATH}" pushP

	PATH="$PATH:$(cygpath -W):$(cygpath -S):$(cygpath -S)/Wbem:$(cygpath -S)/WindowsPowerShell/v1.0/"
	
	export NATIVE_TEMP=$(native_path "$TEMP")
	
	function wrapCommand() {
		local CMD="$1"
		local ERR_MSG="$2"
		local EX="$3"
		local WIN_CMD=$(PATH="$WinPath" command -v "$CMD") || die "required command $CMD not installed on windows\n$ERR_MSG\n"
		echo "#!/bin/sh
export TEMP='${NATIVE_TEMP}'
export TMP='${NATIVE_TEMP}'
$EX
export PATH=\"\$(echo \$PATH | sed 's|${RELEASE_ROOT}/bin:||g')\"
exec '$WIN_CMD' \"\$@\"
" > "${RELEASE_ROOT}/bin/$CMD"
		chmod a+x "${RELEASE_ROOT}/bin/$CMD"
	}

	wrapCommand git "HOME='$REAL_HOME'" "install it from git-scm"
	wrapCommand python "" "'windows-build-tools' is required"
else
	function wrapCommand() {
		local CMD="$1"
		local ERR_MSG="$2"
		local EX="$3"
		local ABS_CMD=$(PATH="$WinPath" command -v "$CMD") || die "required command $CMD not installed\n$ERR_MSG\n"
		echo "#!/bin/sh
$EX
export PATH=\"\$(echo \$PATH | sed 's|${RELEASE_ROOT}/bin:||g')\"
exec '$ABS_CMD' \"\$@\"
" > "${RELEASE_ROOT}/bin/$CMD"
		chmod a+x "${RELEASE_ROOT}/bin/$CMD"
	}
	
	wrapCommand git "HOME='$REAL_HOME'" ""
	wrapCommand python "" ""
fi

export TMP="$(native_path "${RELEASE_ROOT}/tmp")"
export TEMP="${TMP}"

CMD_GIT=$(command -v git)
function git() {
	TMP="$NATIVE_TEMP" TEMP="$NATIVE_TEMP" "$CMD_GIT" "$@"
}

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
echo -e "\e[1;38;5;9m\$BASH_SOURCE\e[0m=\e[2m${BASH_SOURCE[@]}\e[0m"
echo -e "\e[1;38;5;9mSYSTEM\e[0m=\e[2m${SYSTEM}\e[0m"
echo -e "\e[1;38;5;9mARCH\e[0m=\e[2m${ARCH}\e[0m"
echo -e "\e[1;38;5;9mVSCODE_ROOT\e[0m=\e[2m${VSCODE_ROOT}\e[0m"
echo -e "\e[1;38;5;9mYARN_CACHE_FOLDER\e[0m=\e[2m${YARN_CACHE_FOLDER}\e[0m"
echo -e "\e[1;38;5;9mRELEASE_ROOT\e[0m=\e[2m${RELEASE_ROOT}\e[0m"
echo -e "\e[1;38;5;9mARCH_RELEASE_ROOT\e[0m=\e[2m${ARCH_RELEASE_ROOT}\e[0m"
echo -e "\e[1;38;5;9mPATH\e[0m=\e[2m${PATH}\e[0m"
echo -e "\e[1;38;5;9mTEMP\e[0m=\e[2m${TEMP}\e[0m"
echo -e "\e[1;38;5;9mREAL_HOME\e[0m=\e[2m${REAL_HOME}\e[0m"
echo -e "\e[1;38;5;9mHOME\e[0m=\e[2m${HOME}\e[0m"
echo -e "\e[1;38;5;9mFOUND_CYGWIN\e[0m=\e[2m${FOUND_CYGWIN}\e[0m"
echo -e "\e[1;38;5;9mNODEJS\e[0m=\e[2m${NODEJS}\e[0m"
echo -e "\e[1;38;5;9mNODEJS_BIN\e[0m=\e[2m${NODEJS_BIN}\e[0m"
echo -e "\e[1;38;5;9mHTTP_PROXY\e[0m=\e[2m${HTTP_PROXY}\e[0m"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
