# setup_ansible-target-node

**ATTENTION: これは公開リポジトリです**。

ansible-playbook の実行対象となる target node をセットアップするためのもの。
外部に公開したくなかったが、セットアップ処理の利便性の都合で公開している。

外部からのPR等は一切受け付ける予定はない。

## Usage

<install>

```
## default (3.12)
curl -LsSf https://raw.githubusercontent.com/link-u/setup_ansible-target-node/refs/heads/main/install-uv-python4ansible.bash | bash

## 3.14
curl -LsSf https://raw.githubusercontent.com/link-u/setup_ansible-target-node/refs/heads/main/install-uv-python4ansible.bash | UV_PYTHON_VERSION=3.14 bash

## 実行例
root@test-target-u18:~# curl -LsSf https://raw.githubusercontent.com/link-u/setup_ansible-target-node/refs/heads/main/install-uv-python4ansible.bash | bash
root@test-target-u18:~# /usr/local/lib/python4ansible/python3 --version
Python 3.12.13
```

<ansible-playbook>

```
[all:vars]
ansible_python_interpreter="/usr/local/lib/python4ansible/python3"
```


## Purpose

古い OS だと、最新版の ansible を使うために必要な python version が不足するため。
様々な version の OS で ansible-playbook を安定して利用するためには、

- Ansible のサポート
    - https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html
- uv のサポート
    https://docs.astral.sh/uv/reference/policies/platforms/#linux-versions

| Ansible Community Package                                                                                   | Status                      | Core                                                                                       | Core EOL      | Control Node Python | Target Python / PowerShell         |
| -------------------------------------------------------------------------------------------------------- | --------------------------- | ------------------------------------------------------------------------------------------ | ------------- | ------------------- | ---------------------------------- |
| 14.0.0                                                                                                   | In development (unreleased) | 2.21                                                                                       | N/A           | N/A                 | N/A                                |
| [13.x Changelogs](https://github.com/ansible-community/ansible-build-data/blob/main/13/CHANGELOG-v13.md) | Current- Latest             | [2.20](https://github.com/ansible/ansible/blob/stable-2.20/changelogs/CHANGELOG-v2.20.rst) | May 2027      | Python 3.12 - 3.14  | Python 3.9 - 3.14 / PowerShell 5.1 |
| [12.x Changelogs](https://github.com/ansible-community/ansible-build-data/blob/main/12/CHANGELOG-v12.md) | EOL in Dec 2025             | [2.19](https://github.com/ansible/ansible/blob/stable-2.19/changelogs/CHANGELOG-v2.19.rst) | Nov 2026      | Python 3.11 - 3.13  | Python 3.8 - 3.13 / PowerShell 5.1 |
| [11.x Changelogs](https://github.com/ansible-community/ansible-build-data/blob/main/11/CHANGELOG-v11.md) | EOL in Dec 2025             | [2.18](https://github.com/ansible/ansible/blob/stable-2.18/changelogs/CHANGELOG-v2.18.rst) | May 2026      | Python 3.11 - 3.13  | Python 3.8 - 3.13 / PowerShell 5.1 |
| [10.x Changelogs](https://github.com/ansible-community/ansible-build-data/blob/main/10/CHANGELOG-v10.md) | Unmaintained (end of life)  | [2.17](https://github.com/ansible/ansible/blob/stable-2.17/changelogs/CHANGELOG-v2.17.rst) | EOL Nov 2025  | Python 3.10 - 3.12  | Python 3.7 - 3.12 / PowerShell 5.1 |
| [9.x Changelogs](https://github.com/ansible-community/ansible-build-data/blob/main/9/CHANGELOG-v9.rst)   | Unmaintained (end of life)  | [2.16](https://github.com/ansible/ansible/blob/stable-2.16/changelogs/CHANGELOG-v2.16.rst) | EOL July 2025 | Python 3.10 - 3.12  | Python 2.7Python 3.                |


Ubuntu 毎の glibc は以下の通り。

```
$ for i in u{16,18,20,22,24}; do echo -n "[$i]: "; lxc exec test-target-$i -- ldd --version | grep GLIBC; done
[u16]: ldd (Ubuntu GLIBC 2.23-0ubuntu11.3) 2.23
[u18]: ldd (Ubuntu GLIBC 2.27-3ubuntu1.6) 2.27
[u20]: ldd (Ubuntu GLIBC 2.31-0ubuntu9.18) 2.31
[u22]: ldd (Ubuntu GLIBC 2.35-0ubuntu3.13) 2.35
[u24]: ldd (Ubuntu GLIBC 2.39-0ubuntu8.7) 2.39

```

また、uv はきちんと glibc に対応した python binary をインストールしていた。

```
root@test-target-u16:~# for i in {10..14}; do uv venv --python "3.${i}" "py3${i}"; done
root@test-target-u16:~# for i in {10..14}; do pushd  "py3$i"; uv pip install packaging; popd; done

root@test-target-u16:~# for i in {10..14}; do "py3$i/bin/python3" -c "import platform; print(platform.libc_ver())"; done 
('glibc', '2.23')
('glibc', '2.23')
('glibc', '2.23')
('glibc', '2.23')
('glibc', '2.23')
root@test-target-u16:~# for i in {10..14}; do echo -n "py3$i: "; "py3$i/bin/python3" -c "from packaging import tags; print(next(tags.sys_tags()))"; done
py310: cp310-cp310-manylinux_2_23_x86_64
py311: cp311-cp311-manylinux_2_23_x86_64
py312: cp312-cp312-manylinux_2_23_x86_64
py313: cp313-cp313-manylinux_2_23_x86_64
py314: cp314-cp314-manylinux_2_23_x86_64

```



## Verify

```
- hosts: "production"
  become: yes
  gather_facts: yes
  pre_tasks:
  - name: "Check IP address for deploy"
    debug:
      var: ansible_host
    tags: [ "always", "check" ]
  tasks:
  #- name: Show control node python
  #  delegate_to: localhost
  #  run_once: true
  #  debug:
  #    msg: "Control node Python: {{ ansible_playbook_python }}"

  - name: Show target node python version
    debug:
      msg: "Target node Python: {{ ansible_python_version }}"

```

```
TASK [Show target node python version] **********
ok: [test-target-u16] => {
    "msg": "Target node Python: 3.12.13"
}
ok: [test-target-u18] => {
    "msg": "Target node Python: 3.12.13"
}
ok: [test-target-u20] => {
    "msg": "Target node Python: 3.12.13"
}
ok: [test-target-u22] => {
    "msg": "Target node Python: 3.12.13"
}
ok: [test-target-u24] => {
    "msg": "Target node Python: 3.12.13"
}
```

