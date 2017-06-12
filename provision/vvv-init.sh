#!/usr/bin/env bash
# Provision WordPress Stable

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".dev`
DOMAINS=`get_hosts "${DOMAIN}"`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-load.php" ]]; then
    echo "Downloading WordPress..."
	noroot wp core download --version="${WP_VERSION}"
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP
fi

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"

  # Install Plugins
  echo "Installing plugins..."
  noroot wp plugin install wordpress-importer --activate
  noroot wp plugin install developer --activate
  noroot wp plugin install theme-check --activate
  noroot wp plugin install theme-mentor --activate
  noroot wp plugin install what-the-file --activate
  noroot wp plugin install wordpress-database-reset --activate
  noroot wp plugin install rtl-tester
  noroot wp plugin install piglatin
  noroot wp plugin install debug-bar  --activate
  noroot wp plugin install debug-bar-console  --activate
  noroot wp plugin install debug-bar-cron  --activate
  noroot wp plugin install debug-bar-extender  --activate
  noroot wp plugin install rewrite-rules-inspector  --activate
  noroot wp plugin install log-deprecated-notices  --activate
  noroot wp plugin install log-deprecated-notices-extender  --activate
  noroot wp plugin install log-viewer  --activate
  noroot wp plugin install monster-widget  --activate
  noroot wp plugin install user-switching  --activate
  noroot wp plugin install regenerate-thumbnails  --activate
  noroot wp plugin install simply-show-ids  --activate
  noroot wp plugin install theme-test-drive  --activate
  noroot wp plugin install wordpress-beta-tester  --activate

  # Import the unit data.
  echo "Installing unit test data..."
  curl -O https://wpcom-themes.svn.automattic.com/demo/theme-unit-test-data.xml
  noroot wp import theme-unit-test-data.xml --authors=create
  rm theme-unit-test-data.xml

  # Replace url from unit data
  echo "Adjusting urls in database..."
  noroot wp search-replace "wpthemetestdata.wordpress.com" "${DOMAIN}" --skip-columns=guid

  # Install Sage
  echo "Downloading Sage Theme..."
  cd ${VVV_PATH_TO_SITE}/public_html/wp-content/themes/
  # noroot wp theme install 'https://github.com/gkmurray/sage/archive/develop.zip'

  # Download via curl
  curl -LO https://github.com/gkmurray/sage/archive/develop.zip

  echo "Extracting..."
  unzip develop.zip
  mv develop sage
  rm develop.zip

  # Install theme dependencies
  echo "Installing Sage dependencies..."
  cd sage
  noroot composer install


else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core update --version="${WP_VERSION}"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{DOMAINS_HERE}}#${DOMAINS}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
