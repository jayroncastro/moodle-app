FROM debian:stable-slim AS buildstage

LABEL stage="builder"

RUN groupadd -g 1234 docker && useradd -m -d /home/customuser -u 1234 -g docker -s /bin/bash customuser

RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-transport-https \
  lsb-release \
  ca-certificates \
  wget unzip && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

WORKDIR /app

RUN wget https://download.moodle.org/download.php/direct/stable405/moodle-4.5.2.tgz && wget https://download.moodle.org/download.php/direct/langpack/4.5/pt_br.zip && tar -xvzf moodle-4.5.2.tgz

RUN mkdir ./lang

RUN unzip pt_br.zip -d ./lang

COPY --chmod=750 ./bash-files/change-permission-moodle.sh .

RUN ./change-permission-moodle.sh && rm -f ./moodle-4.5.2.tgz && rm -f ./pt_br.zip

#################
## End Stage 1 ##
#################

FROM debian:stable-slim

LABEL maintainer="Jayron Castro<jayroncastro@gmail.com>"
LABEL description="Container to run the Moodle 4.5.2 virtual environment using debian bookworm."

RUN groupadd -g 1234 docker && useradd -m -d /home/customuser -u 1234 -g docker -s /bin/bash customuser

RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-transport-https \
  lsb-release \
  ca-certificates \
  wget && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' && apt-get update && apt-get install -y --no-install-recommends \
  supervisor \
  supervisor-doc- \
  cron \
  vim \
  vim-doc- \
  iproute2 \
  iproute2-doc- \
  apache2 \
  apache2-doc- \
  perl-doc- \
  libapache2-mod-php8.2 \
  php8.2-bcmath \
  php8.2-curl \
  php8.2-gd \
  php8.2-intl \
  php8.2-mbstring \
  php8.2-mysql \
  php8.2-soap \
  php8.2-xml \
  php8.2-xmlrpc \
  php8.2-xsl \
  php8.2-zip && apt-get --purge autoremove -y wget lsb-release apt-transport-https ca-certificates && apt-get clean && apt-get autoclean && apt-get --purge autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && rm -rf /var/www/html && ln -s /home/customuser/moodle /var/www/html

COPY ./config-files/apache2.conf /etc/apache2/
COPY --chmod=775 ./config-files/envvars /etc/apache2/
COPY ./config-files/security.conf /etc/apache2/conf-available/
COPY ./config-files/php.ini /etc/php/8.2/apache2/

WORKDIR /home/customuser/moodle

COPY ./config-files/moodle.sh /home/customuser/
COPY --chmod=600 ./config-files/customuser /var/spool/cron/crontabs/
COPY ./config-files/vimrc /etc/vim/
COPY --chmod=775 ./config-files/supervisor/supervisord.conf /etc/supervisor/
COPY --chmod=775 ./config-files/supervisor/apache2.conf /etc/supervisor/conf.d/
COPY --chmod=775 ./config-files/supervisor/cron.conf /etc/supervisor/conf.d/

RUN mkdir -p /home/customuser/moodledata/lang && chmod -R 2770 /home/customuser && chown -R customuser:docker /home/customuser && usermod -aG www-data customuser && usermod -aG crontab customuser

COPY --from=buildstage /app/moodle .
COPY --from=buildstage /app/lang /home/customuser/moodledata/lang

RUN chown -R root:docker /etc/apache2 && chown -R root:docker /var/log && chmod -R 2770 /var/log && chown -R root:docker /var/run && chmod -R 2770 /var/run/ && chmod 4775 /usr/bin/supervisord && chmod 4775 /usr/bin/python3.11 && chown -R root:docker /usr/lib/python3 && chown -R root:docker /usr/lib/python3.11 && chown -R root:docker /run && chown customuser:crontab /var/spool/cron/crontabs/customuser && chown root:crontab /usr/sbin/cron && chmod 4775 /usr/sbin/cron

EXPOSE 80 443
CMD ["/usr/bin/supervisord"]

USER customuser