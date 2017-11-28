#!/bin/bash -x

uid=`id -u`
guid=`id -g`
export uid
export guid
docker container stop mx-nginx mx-php-fpm mx-httpd
docker container rm mx-nginx mx-php-fpm mx-httpd
docker volume rm mx-code

docker volume create --name mx-code -o device=`pwd`/../www -o o=bind  
docker-compose -f ../env/docker-compose.yml up -d --build --remove-orphans  

docker exec -uroot chown -R www-data /www
docker exec -uroot mx-php-fpm /bin/rm -rf /www/magento2ce/var/* /www/magento2ce/generated/* /www/magento2ce/pub/static/* /www/magento2ce/app/etc/env.php
docker exec -uroot mx-php-fpm /bin/rm -rf /www/magento1/var/* /www/magento1/app/etc/local.xml
docker exec -uwww-data mx-php-fpm composer clear-cache --working-dir /www/magento2ce
docker exec -uwww-data mx-php-fpm composer install --working-dir /www/magento2ce 
docker exec mx-mysql mysql -uroot -h127.0.0.1 -p123123q -e "DROP DATABASE IF EXISTS magento2; CREATE DATABASE magento2;"
docker exec mx-mysql mysql -uroot -h127.0.0.1 -p123123q -e "DROP DATABASE IF EXISTS magento1; CREATE DATABASE magento1;"
docker exec -uwww-data mx-php-fpm chmod +x /www/magento2ce/bin/magento 
docker exec -u www-data mx-php-fpm \
  /www/magento2ce/bin/magento setup:install \
  --backend-frontname="admin"  \
  --db-host="mx-mysql"  \
  --db-name="magento2"  \
  --db-user="root"  \
  --db-password="123123q"  \
  --db-prefix="pr_"  \
  --base-url="http://m2.dev"  \
  --use-rewrites="1"  \
  --use-secure="1"  \
  --use-secure-admin="1"  \
  --admin-use-security-key="0"  \
  --admin-user="admin"  \
  --admin-password="123123q"  \
  --admin-email="magento@magento.com"  \
  --admin-firstname="Magento"  \
  --admin-lastname="Magento"  \
  --language="en_US"  \
  --timezone="Europe/Kiev"  \
  --currency="USD"

docker exec -u www-data mx-php-fpm /www/magento2ce/bin/magento indexer:reindex
docker exec -u www-data mx-php-fpm /www/magento2ce/bin/magento cache:clean
docker exec mx-mysql mysql -uroot  -h127.0.0.1 -p123123q -e "INSERT INTO magento2.pr_core_config_data(path, value) VALUES('admin/security/admin_account_sharing', 1)"
docker exec mx-mysql mysql -uroot  -h127.0.0.1 -p123123q -e "INSERT INTO magento2.pr_core_config_data(path, value) VALUES('cms/wysiwyg/enabled', 'disabled')"
