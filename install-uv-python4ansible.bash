# /bin/bash -

set -euo pipefail

# =====================
# Environment Variables
# =====================
UV_INSTALL_DIR="/usr/local/bin"

UV_USER="python4ansible"
UV_GROUP="${UV_USER}"
UV_BASE_DIR="/usr/local/lib"

UV_PYTHON_VERSION="${UV_PYTHON_VERSION:-3.12}"   # Python
UV_VENV_DIR="python${UV_PYTHON_VERSION}"
UV_PYTHON_SYMLINK="python3" # used by ansible_python_interpreter

UV_PIP_PKGS=()

## 1. check required commands
for i in curl sudo; do
  command -v "$i" >/dev/null 2>&1
  if [ "$?" -ne "0" ]; then
	    command echo "ERROR: command not found: $i" >&2
	    exit 1
  fi
done

## 2. install uv
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="${UV_INSTALL_DIR}" sh
"${UV_INSTALL_DIR}/uv" --version


## 3. create user & home directory
set +e
getent passwd "${UV_USER}" >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
	useradd -r -m -b "${UV_BASE_DIR}" -s /sbin/nologin "${UV_USER}"
fi
set -e

## 4. create uv venv

pushd "${UV_BASE_DIR}/${UV_USER}" ## `env -C` is not supported in Ubuntu 16.04, 18.04

if [ -d "${UV_VENV_DIR}_tmp" ]; then
	rm -rf "${UV_VENV_DIR}_tmp"
fi

sudo -u "${UV_USER}" -g "${UV_GROUP}" \
	UV_PYTHON_PREFERENCE="only-managed" \
	HOME="${UV_BASE_DIR}/${UV_USER}" \
	"${UV_INSTALL_DIR}/uv" venv --python "${UV_PYTHON_VERSION}" "${UV_VENV_DIR}_tmp"

	if [ "${#UV_PIP_PKGS[@]}"  -gt  0 ]; then
		sudo -u "${UV_USER}" -g "${UV_GROUP}" \
			HOME="${UV_BASE_DIR}/${UV_USER}" \
			"${UV_INSTALL_DIR}/uv" --directory "${UV_BASE_DIR}/${UV_USER}/${UV_VENV_DIR}_tmp" pip install "${UV_PIP_PKGS[@]}"
	fi


if [ -d "${UV_VENV_DIR}" ]; then
	rm -rf "${UV_VENV_DIR}"
fi

mv "${UV_VENV_DIR}_tmp" "${UV_VENV_DIR}"

sudo -u "${UV_USER}" -g "${UV_GROUP}" \
	ln -sfn "${UV_VENV_DIR}/bin/python3" "${UV_PYTHON_SYMLINK}"

command echo "ansible_python_interpreter=\"${UV_BASE_DIR}/${UV_USER}/${UV_PYTHON_SYMLINK}\""

