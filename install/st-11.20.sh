#!/bin/bash
spinner() {
  PID=$1
  text=$2
  chars="◷◶◵◴"

  while [ -d /proc/$PID ]; do
    for (( i=0; i<${#chars}; i++ )); do
      sleep 0.2
      echo -en " ${chars:$i:1}" "$text\r"
    done
  done
  echo -en " - $text\n"
}

clear
echo -e "************************************************\n*                                              *\n*          Streamtool autoinstaller            *\n*                                              *\n************************************************"
echo ""

echo "Cleaning mount point & user"
{
  systemctl stop streamtool-webserver streamtool-fpm streamtool
  cd /opt/
  killall ffmpeg
  while [ ! -z "`mount -l | grep '/opt/streamtool/app/www/hl'`" ]; do 
    umount /opt/streamtool/app/www/hl
    sleep .1
  done
  crontab -r -u streamtool
  rm -rf /opt/streamtool
  userdel streamtool
} &>/dev/null

echo ""
echo "Updating system"

apt-get update >/dev/null 2>&1 &
PID=$!
spinner $PID "repositories"

apt-get full-upgrade --allow-downgrades --allow-remove-essential --allow-unauthenticated -y >/dev/null 2>&1 &
PID=$!
spinner $PID "Full upgrade"

apt-get autoremove --allow-downgrades --allow-remove-essential --allow-unauthenticated -y >/dev/null 2>&1 &
PID=$!
spinner $PID "Removing unnecessary packages"

apt-get install --allow-downgrades --allow-remove-essential --allow-unauthenticated -y sudo curl nano wget zip unzip git lsof iftop htop ca-certificates net-tools xml-twig-tools libgeoip1 libqdbm14 libxdmcp6 libxml2 libxslt1.1 libxpm4 libcurl4 libmhash2 libpcre3 libpopt0 libpq5 libsensors-config libsm6 libpng16-16 libfreetype6 libc6 zlib1g libxau6 libxcb1 libssh2-1 libgd3 libtidy5deb1 libonig5 ffmpeg libavcodec-extra58 libavfilter-extra7 >/dev/null 2>&1 &
PID=$!
spinner $PID "Installing ubuntu required packages"

echo ""
echo ""
echo "Installing Streamtool"

git clone https://github.com/NeySlim/streamtool >/dev/null 2>&1 &
PID=$!
spinner $PID "Downloading software"

echo " - Configuring system"

{
  /usr/sbin/useradd -s /sbin/nologin -U -d /opt/streamtool -m streamtool
  grep -qxF 'streamtool ALL = (root) NOPASSWD: /usr/bin/systemctl'  /etc/sudoers || echo 'streamtool ALL = (root) NOPASSWD: /usr/bin/systemctl' >>/etc/sudoers
  grep -qxF 'streamtool ALL=(ALL) NOPASSWD: /tmp/patch.sh'  /etc/sudoers || echo 'streamtool ALL=(ALL) NOPASSWD: /tmp/patch.sh' >>/etc/sudoers
  cp /opt/streamtool/install/files/streamtool*.service /etc/systemd/system/.
  systemctl daemon-reload
  systemctl enable streamtool streamtool-webserver streamtool-fpm
  echo "$(
    date +%s | sha256sum | base64 | head -c 32
    echo
  )" > ~/STREAMTOOL_MYSQL_PASSWORD
  sqlpasswd=($(cat ~/STREAMTOOL_MYSQL_PASSWORD))
} &>/dev/null

echo ""
echo ""
echo "Database Installation"
#Database install and configuration
sudo apt-get -y install mariadb-server mariadb-client >/dev/null 2>&1 &
PID=$!
spinner $PID "Downloading and installing stock mariadb"
echo " - Configuring custom mariadb options"

{
  grep -qxF "default-authentication-plugin = mysql_native_password" /etc/mysql/mariadb.conf.d/50-server.cnf || sed '/\[mysqld\]/a # set default password auth\
default-authentication-plugin = mysql_native_password\' -i /etc/mysql/mariadb.conf.d/50-server.cnf
  grep -qxF 'sql-mode="ALLOW_INVALID_DATES,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"' /etc/mysql/mariadb.conf.d/50-server.cnf || sed '/\[mysqld\]/a # set ugly date mode\
sql-mode="ALLOW_INVALID_DATES,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"\' -i /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/query_cache_size        = 16M/key_buffer_size = 128M\n\nmyisam_sort_buffer_size = 4M\nmax_allowed_packet      = 64M\nmyisam-recover-options = BACKUP\nmax_length_for_sort_data = 8192\nquery_cache_limit       = 4M\nquery_cache_size        = 0\nquery_cache_type        = 0\nexpire_logs_days        = 10\nmax_binlog_size         = 100M\nmax_connections  = 4000\nback_log = 4096\nopen_files_limit = 16384\ninnodb_open_files = 16384\nmax_connect_errors = 3072\ntable_open_cache = 8192\ntable_definition_cache = 4096\njoin_buffer_size = 768\ntmp_table_size = 1G\nmax_heap_table_size = 1G\ninnodb_buffer_pool_size = 2G\ninnodb_buffer_pool_instances = 2\ninnodb_read_io_threads = 64\ninnodb_write_io_threads = 64\ninnodb_thread_concurrency = 0\ninnodb_flush_log_at_trx_commit = 0\ninnodb_flush_method = O_DIRECT\nperformance_schema = ON\ninnodb-file-per-table = 1\ninnodb_io_capacity=20000\ninnodb_table_locks = 0\ninnodb_lock_wait_timeout = 0\ninnodb_deadlock_detect = 0\ninnodb_log_file_size = 256M/g' /etc/mysql/mariadb.conf.d/50-server.cnf
  systemctl restart mariadb

  mysql -uroot -e "CREATE DATABASE streamtool"
  mysql -uroot -e "DROP USER 'streamtool'@'localhost'"
  mysql -uroot -e "CREATE USER 'streamtool'@'localhost' identified by '$sqlpasswd'"
  mysql -uroot -e "grant all privileges on streamtool.* to 'streamtool'@'localhost'"
} &>/dev/null

echo ""
echo ""
echo "Finishing"
echo "  - Last config"
{
  sed -i 's/xxx/streamtool/g' /opt/streamtool/app/www/config.php
  sed -i 's/zzz/'$sqlpasswd'/g' /opt/streamtool/app/www/config.php
  sed -i 's/ttt/streamtool/g' /opt/streamtool/app/www/config.php

  ln -sf /opt/streamtool/app/nginx/sbin/nginx /opt/streamtool/app/nginx/sbin/nginx_streamtool

  mkdir -p /opt/streamtool/app/www/cache
  chmod -R 777 /opt/streamtool/app/www/cache
  mkdir -p /opt/streamtool/app/www/hl
  mkdir -p /opt/streamtool/app/nginx/pid
  mkdir -p /opt/streamtool/app/nginx/client_body_temp
  mkdir -p /opt/streamtool/app/nginx/fastcgi_temp
  mkdir -p /opt/streamtool/app/nginx/proxy_temp
  mkdir -p /opt/streamtool/app/nginx/scgi_temp
  mkdir -p /opt/streamtool/app/php/var/run
  mkdir -p /opt/streamtool/app/logs/
  mount /opt/streamtool/app/www/hl
  mkdir -p /opt/streamtool/app/wws/
  mkdir -p /opt/streamtool/app/wws/log/
  cd /opt/streamtool/app/www/
for FILE in *
do
    if test -d $FILE
    then
      ln -s /opt/streamtool/app/www/$FILE /opt/streamtool/app/wws/$FILE
    fi
done
  ln -s /opt/streamtool/app/www/config /opt/streamtool/app/wws/config
  ln -s /opt/streamtool/app/www/config.php /opt/streamtool/app/wws/config.php
  ln -s /opt/streamtool/app/www/functions.php /opt/streamtool/app/wws/functions.php
  ln -s /opt/streamtool/app/www/stream.php /opt/streamtool/app/wws/stream.php
  ln -s /opt/streamtool/app/www/mpegts.php /opt/streamtool/app/wws/mpegts.php
  ln -s /opt/streamtool/app/www/playlist.php /opt/streamtool/app/wws/playlist.php
  grep -qxF 'tmpfs /opt/streamtool/app/www/hl/ tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=80% 0 0' /etc/fstab || echo 'tmpfs /opt/streamtool/app/www/hl/ tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=80% 0 0' >>/etc/fstab
  
  ln -s /opt/streamtool/app/www/hl /opt/streamtool/app/wws/hl

  chown -R streamtool. /opt/streamtool

  (
    crontab -u streamtool -l 2>/dev/null
    echo "*/1 * * * * /opt/streamtool/app/php/bin/php /opt/streamtool/app/www/cron.php"
  ) | crontab -u streamtool -
} &>/dev/null

echo ""
echo ""
streamPort=`mysql -uroot -Nse "SELECT webport FROM streamtool.settings"`
if [ "$?" == "0" ]; then
  sed -i 's/listen 8000/listen '${streamPort}'/g' /opt/streamtool/app/nginx/conf/nginx.conf
fi
systemctl start streamtool
sleep 5 &
PID=$!
spinner $PID "Starting Streamtool Webserver"
{
  curl -s http://127.0.0.1:9001/install_database_tables.php?install
  curl -s http://127.0.0.1:9001/install_database_tables.php?update
  mv /opt/streamtool/app/www/install_database_tables.php /opt/streamtool/install/files/.
} &>/dev/null

echo ""
echo -e "**************************************************\n*                                                *\n*          Streamtool install complete           *\n*                                                *\n*          http://$(hostname -I | cut -d ' ' -f1):9001\n*       Username: admin  Password: admin         *\n*                                                *\n**************************************************"
