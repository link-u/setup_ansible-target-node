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
UV_SYMLINK="venv" # used by ansible_python_interpreter

UV_PIP_PKGS=('packaging' 'pymysql' 'zabbix-api' 'requests' 'passlib')

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
	sudo chmod 755 "${UV_BASE_DIR}/${UV_USER}"
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
	ln -sfn "${UV_VENV_DIR}" "${UV_SYMLINK}"

sudo chmod 755 "${UV_VENV_DIR}" "${UV_VENV_DIR}/bin"

INTERNAL_PYTHON_EXE=$(readlink -f "${UV_VENV_DIR}/bin/python3")
sudo chmod a+x "${INTERNAL_PYTHON_EXE}"

popd

## 5. Configure APT Hook for uv self update
command echo "==> Configuring APT hook for uv auto-update..."

# Create uv update script
sudo tee /usr/local/bin/apt-uv-updater.sh > /dev/null << 'EOF'
#! /bin/bash -

# uvコマンドが存在するかチェック
if command -v uv >/dev/null 2>&1; then
    command echo '========== [APT Hook] Updating /usr/local/bin/uv =========='
    
    # 2>&1 でエラー出力を標準出力に統合し、ifの条件式として実行する
    if ! uv self update 2>&1; then
        # uv self update が失敗（非ゼロ）した場合、警告メッセージを出して正常終了させる
        command echo ' [WARNING] uv self update failed. Skipping to avoid disrupting APT.' >&2
    fi
fi

# 何があってもAPT側には「成功した」と嘘をついて正常終了させる
exit 0
EOF

# Grant execution permission
sudo chmod +x /usr/local/bin/apt-uv-updater.sh

# Create APT configuration file
sudo tee /etc/apt/apt.conf.d/99uv-auto-update > /dev/null << 'EOF'
#DPkg::Post-Invoke { "/usr/local/bin/apt-uv-updater.sh"; };
APT::Update::Post-Invoke { "/usr/local/bin/apt-uv-updater.sh"; };
EOF


# =====================
# Output Result
# =====================
command echo "ansible_python_interpreter=\"${UV_BASE_DIR}/${UV_USER}/${UV_SYMLINK}/bin/python3\""

