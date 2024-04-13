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

runcmd:
- /root/install_task.sh
- /root/install_ringgem.sh
EOF

incus ls --format=json | jq 'map(select(.name == "{{.ContainerName}}")) | .[] | .name' | xargs --no-run-if-empty -I {} incus delete --force {}
incus launch {{.BaseImage}} {{.ContainerName}} --config=user.user-data="$(cat {{.ContainerName}}.yml)"
incus exec {{.ContainerName}} -- cloud-init status --wait
incus exec {{.ContainerName}} shutdown now
incus config set {{.ContainerName}} boot.autostart false

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
