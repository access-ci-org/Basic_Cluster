#!/usr/bin/env bash
ver="1.6.1"
file="node_exporter-${ver}.linux-amd64.tar.gz"
sha256=sha256sums.txt

# cd to the script directory, in case the user has run it from another directory
sriptdir=$(cd "$(dirname "$0")" && pwd)
cd $sriptdir

if [[ ! -f $file ]]; then
  echo "Downloading $file from Github"
  curl -L https://github.com/prometheus/node_exporter/releases/download/v${ver}/${file} -o $file
fi

echo "Downloading the $sha256 checksum file"
curl -L https://github.com/prometheus/node_exporter/releases/download/v${ver}/$sha256 -o $sha256

if ! grep $file $sha256 | sha256sum -c -; then
	echo "checksum failed for $file, exitting" >&2
	exit 1
else
	echo "Checksum of $file: OK"
fi

if [[ ! -d tmp/${file%.tar.gz} ]]; then
	echo "Extracting $file to tmp/"
  tar -zxf $file -C tmp/
fi

echo "Adding system user: node_exporter"
useradd -rs /bin/false node_exporter

echo "Copying node_exporter binary to /usr/local/bin"
systemctl is-active --quiet node_exporter.service && systemctl stop node_exporter.service
cp tmp/${file%.tar.gz}/node_exporter /usr/local/bin/
chown root:root /usr/local/bin/node_exporter

echo "Creating /etc/systemd/system/node_exporter.service file"
cp node_exporter.service /etc/systemd/system/

echo "Starting node_exporter.service"
systemctl daemon-reload
systemctl enable node_exporter.service
systemctl start node_exporter.service

## Host based firewall rules to allow incoming scrapes on `9100/tcp`
## from the Prometheus public IP

#echo "Creating firewalld rule to allow Prometheus server access to 9100/tcp"
#firewall-cmd --zone=public --permanent --add-rich-rule='rule family="ipv4" source address="172.20.0.99" port protocol="tcp" port="9100" accept'
#firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="172.20.0.99" port protocol="tcp" port="9100" accept'

