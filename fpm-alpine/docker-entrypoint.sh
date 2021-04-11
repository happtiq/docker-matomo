#!/bin/sh
set -e

LOG_LEVEL=${LOG_LEVEL:-WARN}

if [ ! -s "/data/geoip" ]; then
    mkdir -p /data/geoip
fi

if [ ! -s "/data/config" ]; then
    mkdir -p /data/config
fi

chown -R www-data:www-data /data

if [ ! -e matomo.php ]; then
	cp -r /usr/src/matomo/* /var/www/html/
	#chown -R www-data:www-data .
    chown -R www-data:www-data /var/www/html/
fi

# Switch the plugins directory to persistent volume if mountpoint available
if [ -d "/plugins" ]; then
    echo "Plugin sync configured... /plugin exists"
    if [ -d "/var/www/html/plugins" ]; then
        echo "Local plugin directory found in /var/www/html/plugins..."
        if [ ! -f "/plugins/SYNC_IN_PROGRESS.lock"]; then
            echo "Starting plugin sync..."
            #cp -Rf /var/www/html/plugins/. /plugins/
            touch /plugins/SYNC_IN_PROGRESS.lock
            rsync -aW --no-compress /var/www/html/plugins/. /plugins/
            mv /var/www/html/plugins /var/www/html/plugins.docker
            rm /plugins/SYNC_IN_PROGRESS.lock
            echo "Completed plugin sync..."
        fi
    fi
    if [ ! -L "/var/www/html/plugins" ]; then
        echo "Creating symlink for plugin directory..."
        mv /var/www/html/plugins /var/www/html/plugins.docker
        ln -s /plugins /var/www/html/plugins
    fi
fi

cp -Rf /var/www/html/config /data/

if [ ! -s "/data/geoip/DBIP-City.mmdb"]; then
    mv /var/geoip/DBIP-City.mmdb /data/geoip/DBIP-City.mmdb
fi

if [ ! -s "/var/www/html/misc/DBIP-City.mmdb" ]; then
    ln -s /data/geoip/DBIP-City.mmdb /var/www/html/misc/DBIP-City.mmdb
fi

# Check if already installed
if [ -f /data/config/config.ini.php ] || [ -f /config/config.ini.php ]; then
    if [ -f  /config/config.ini.php ]; then
        ln -s /config/config.ini.php /data/config/config.ini.php
    fi
    echo "Setting Matomo log level to $LOG_LEVEL..."
    su www-data -s /bin/sh -c "php /var/www/html/console config:set --section='log' --key='log_level' --value='$LOG_LEVEL'"

    echo "Upgrading and setting Matomo configuration..."
    su www-data -s /bin/sh -c "php /var/www/html/console core:update --yes --no-interaction"
    su www-data -s /bin/sh -c "php /var/www/html/console config:set --section='General' --key='minimum_memory_limit' --value='-1'"
else
    echo ">>"
    echo ">> Open your browser to install Matomo through the wizard"
    echo ">>"
fi

exec "$@"
