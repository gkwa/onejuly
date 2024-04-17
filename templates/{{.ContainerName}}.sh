#!/usr/bin/env bash

set -e

# Generate cloud-init config
cat >{{.ContainerName}}.yml <<'EOF'
#cloud-config
package_update: true
package_reboot_if_required: true

packages:
{{- range .PackageList }}
- {{ . }}
{{- end }}

write_files:

- content: |
    #!/usr/bin/env bash

    set -e
    set -u

    curl -Lo ringgem.zip https://github.com/taylormonacelli/ringgem/archive/refs/heads/master.zip
    unzip -o ringgem.zip -d ringgem # result example: ./ringgem/ringgem-master/install-sops-on-linux.sh

  path: /root/install_ringgem.sh
  append: true
  permissions: "0755"

- content: |
    #!/usr/bin/env bash

    set -e
    set -u

    if ! command task --version &>/dev/null; then
        cd /usr/local
        sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
        /usr/local/bin/task --version
    fi

  path: /root/install_task.sh
  append: true
  permissions: "0755"

- content: |

    set -e
    set -x
    set -u

    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update

    apt-get install --assume-yes unzip curl

    curl -fsSL https://raw.githubusercontent.com/taylormonacelli/ringgem/master/install-go-task-on-linux.sh | sudo bash
    curl -Lo /tmp/ringgem-master.zip https://github.com/taylormonacelli/ringgem/archive/refs/heads/master.zip
    unzip /tmp/ringgem-master.zip -d /tmp/ringgem
    task --output=prefixed --dir=/tmp/ringgem/ringgem-master --verbose install-git-on-linux

    mkdir -p /opt/ringgem
    git --work-tree=/opt/ringgem --git-dir=/opt/ringgem/.git init --quiet

    if ! git --work-tree=/opt/ringgem --git-dir=/opt/ringgem/.git remote show origin >/dev/null 2>&1; then
      git --work-tree=/opt/ringgem --git-dir=/opt/ringgem/.git remote add origin https://github.com/taylormonacelli/ringgem.git
    fi

    git --work-tree=/opt/ringgem --git-dir=/opt/ringgem/.git pull origin master
    git --work-tree=/opt/ringgem --git-dir=/opt/ringgem/.git branch --set-upstream-to=origin/master master
    git --git-dir=/opt/ringgem/.git pull

    ln --force --symbolic /opt/ringgem/Taskfile.yaml /root/Taskfile.yaml

    rm -rf /tmp/ringgem /tmp/ringgem-master.zip

  path: /root/install_ringgem2.sh
  append: true
  permissions: "0755"

runcmd:
- /root/install_task.sh
- /root/install_ringgem.sh
- /root/install_ringgem2.sh

bootcmd:
- |
  bash -c '
  set -e
  set -x
  set -u
  if ! command -v git &>/dev/null; then
    echo exitting, cant find git
    exit 1
  fi
  if [[ -d /opt/ringgem ]]; then
    git --work-tree=/opt/ringgem --git-dir=/opt/ringgem/.git pull origin master
  fi
  '
EOF

incus ls --format=json | jq 'map(select(.name == "{{.ContainerName}}")) | .[] | .name' | xargs --no-run-if-empty -I {} incus delete --force {}
incus launch {{.BaseImage}} {{.ContainerName}} --config=user.user-data="$(cat {{.ContainerName}}.yml)"
incus exec {{.ContainerName}} -- cloud-init status --wait
incus exec {{.ContainerName}} shutdown now
incus config set {{.ContainerName}} boot.autostart=no

# create {{.ContainerName}} image
cmd="incus publish {{.ContainerName}} --alias {{.OutputImageAlias}} --reuse"
sleep 3s # workaround Error: The instance is currently running. Use --force to have it stopped and restarted

if ! timeout 10m bash -c "until $cmd; do sleep 0.25s; done"; then
  echo ERROR: timeout exceeded for command: $cmd
  exit 1
fi

incus ls --format=json | jq 'map(select(.name == "{{.ContainerName}}")) | .[] | .name' | xargs --no-run-if-empty -I {} incus delete --force {}

# ensure {{.ContainerName}} image exists now
incus image list --format=json | jq -e 'map(select(.aliases[].name == "{{.OutputImageAlias}}")) | length > 0' >/dev/null

# launch new image from image we just created
incus launch {{.OutputImageAlias}} {{.ContainerName}}
