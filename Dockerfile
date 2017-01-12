FROM ubuntu:16.04
MAINTAINER Karl Li <killtw@gmail.com>

ENV APP="/var/www/html/app" \
    TERM="xterm" \
    DEBIAN_FRONTEND="noninteractive" \
    ES_HOME=/usr/share/elasticsearch-rtf \
    DEFAULT_ES_USER=elasticsearch \
    DISCOVER_TRANSPORT_IP=eth0 \
    DISCOVER_HTTP_IP=eth0 \
    ES_JAVA_OPTS="-Xms2024m -Xmx2024m"

WORKDIR $APP

# upgrade the container
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common curl \
    git libmcrypt4 libpcre3-dev python2.7-dev \
    python-pip unattended-upgrades vim libnotify-bin wget debconf-utils && \
    apt-add-repository ppa:nginx/stable -y && \
    apt-add-repository ppa:ondrej/php -y && \
    apt-add-repository ppa:brightbox/ruby-ng -y && \
    apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C && \
    sh -c 'echo "deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7" >> /etc/apt/sources.list.d/mysql.list' && \
    curl -s https://packagecloud.io/gpg.key | apt-key add - && \
    curl --silent --location https://deb.nodesource.com/setup_6.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    sh -c 'echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list' && \
    apt-get update && \
    apt-get upgrade -y && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale  && \
    locale-gen en_US.UTF-8 && \
    ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime

COPY .bash_aliases /root

# install nginx
RUN apt-get install -y nginx && \
    rm -rf /etc/nginx/sites-available/default && \
    rm -rf /etc/nginx/sites-enabled/default && \
    ln -fs "/etc/nginx/sites-available/homestead" "/etc/nginx/sites-enabled/homestead" && \
    sed -i -e "s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
    sed -i -e "s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
    echo "daemon off;" >> /etc/nginx/nginx.conf && \
    sed -i -e "s/user www-data;/user root;/" /etc/nginx/nginx.conf && \
    sed -i -e "s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf

RUN apt-get install -y php7.1-fpm php7.1-cli php7.1-dev php7.1-gd \
    php-apcu php7.1-curl php7.1-mcrypt php7.1-imap php7.1-mysql php7.1-readline php-xdebug php-common \
    php7.1-mbstring php7.1-xml php7.1-zip && \
    sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini && \
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.1/fpm/php-fpm.conf && \
    sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i -e "s/www-data/root/g" /etc/php/7.1/fpm/pool.d/www.conf && \
    find /etc/php/7.1/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \; && \
    mkdir -p /run/php/ && chown -Rf www-data.www-data /run/php

RUN echo mysql-server mysql-server/root_password password secret | debconf-set-selections && \
    echo mysql-server mysql-server/root_password_again password secret | debconf-set-selections && \
    apt-get install -y mysql-server redis-server supervisor
COPY my.cnf /etc/mysql/my.cnf
RUN /usr/sbin/mysqld & \
    sleep 10s && \
    echo "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION; CREATE USER 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret'; GRANT ALL ON *.* TO 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION; GRANT ALL ON *.* TO 'homestead'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION; FLUSH PRIVILEGES; CREATE DATABASE homestead;" | mysql

RUN apt-get install -y default-jre && \
    cd /usr/share && \
    git clone git://github.com/medcl/elasticsearch-rtf.git -b 5.0.0 --depth 1 && \
    adduser --system --shell /bin/sh $DEFAULT_ES_USER
COPY elasticsearch /elasticsearch

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer && \
    composer global require hirak/prestissimo && \
    apt-get -y install ruby2.3 nodejs yarn && \
    yarn global add gulp bower && \
    mkdir -p /var/log/supervisor && \
    apt-get remove --purge -y software-properties-common && \
    apt-get autoremove -y && \
    apt-get clean && \
    apt-get autoclean && \
    echo -n > /var/lib/apt/extended_states && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/man/?? && \
    rm -rf /usr/share/man/??_*

COPY homestead /etc/nginx/sites-available/
COPY fastcgi_params /etc/nginx/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
VOLUME ["/var/cache/nginx", "/var/log/nginx", "/var/lib/mysql", "/var/log/supervisor", "/data","/conf"]

EXPOSE 80 443 3306 6379 9200 9300

ENTRYPOINT ["/bin/bash","-c"]
CMD ["/usr/bin/supervisord"]
