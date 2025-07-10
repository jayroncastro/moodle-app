#------------------------------------------------------------------
# Estágio 1: Build - Prepara os arquivos do Moodle
#------------------------------------------------------------------
FROM debian:stable-slim AS buildstage

LABEL stage="builder"

# Restaurada a criação do usuário para o script de permissão funcionar.
RUN groupadd -g 1234 docker && useradd -m -d /home/customuser -u 1234 -g docker -s /bin/bash customuser

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      unzip \
      wget && \
    wget https://download.moodle.org/download.php/direct/stable500/moodle-latest-500.tgz -O moodle.tgz && \
    wget https://download.moodle.org/download.php/direct/langpack/5.0/pt_br.zip -O pt_br.zip && \
    tar -xvzf moodle.tgz && \
    mkdir -p ./lang/pt_br && \
    unzip pt_br.zip -d ./lang/pt_br && \
    rm moodle.tgz pt_br.zip && \
    apt-get purge -y --auto-remove wget unzip && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=750 ./bash-files/change-permission-moodle.sh .
RUN ./change-permission-moodle.sh


#------------------------------------------------------------------
# Estágio 2: Final
#------------------------------------------------------------------
FROM debian:stable-slim

LABEL maintainer="Jayron Castro<jayroncastro@gmail.com>"
LABEL description="Container para rodar o ambiente virtual do Moodle 5.0.1 usando Debian Bookworm."

RUN groupadd -g 1234 docker && useradd -m -d /home/customuser -u 1234 -g docker -s /bin/bash customuser

# Camada de instalação de pacotes, já otimizada e correta.
RUN apt-get update && apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      apache2 \
      cron \
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
      php8.2-zip \
      supervisor && \
    apt-get --purge autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && \
    rm -rf /var/www/html && \
    ln -s /home/customuser/moodle /var/www/html

# Camadas de cópia de configuração, já otimizadas.
COPY ./config-files/apache2.conf /etc/apache2/
COPY --chmod=775 ./config-files/envvars /etc/apache2/
COPY ./config-files/security.conf /etc/apache2/conf-available/
COPY ./config-files/php.ini /etc/php/8.2/apache2/
COPY ./config-files/moodle.sh /home/customuser/
COPY --chmod=600 ./config-files/customuser /var/spool/cron/crontabs/
COPY --chmod=775 ./config-files/supervisor/supervisord.conf /etc/supervisor/
COPY --chmod=775 ./config-files/supervisor/apache2.conf /etc/supervisor/conf.d/
COPY --chmod=775 ./config-files/supervisor/cron.conf /etc/supervisor/conf.d/

WORKDIR /home/customuser

# Copiando arquivos já com o dono correto para evitar um chown massivo.
COPY --from=buildstage --chown=customuser:docker /app/moodle ./moodle
COPY --from=buildstage --chown=customuser:docker /app/lang ./moodledata/lang

# A SOLUÇÃO FINAL: O chmod -R foi removido e substituído por um chmod específico e não-recursivo.
# Esta camada agora será minúscula (KBs, não 471MB).
RUN usermod -aG www-data customuser && \
    usermod -aG crontab customuser && \
    chmod 2770 /home/customuser ./moodle ./moodledata && \
    chown -R root:docker /etc/apache2 /var/log /var/run /usr/lib/python3 /usr/lib/python3.11 /run && \
    chown customuser:crontab /var/spool/cron/crontabs/customuser && \
    chown root:crontab /usr/sbin/cron && \
    chmod -R 2770 /var/log /var/run/ && \
    chmod 4775 /usr/bin/supervisord /usr/bin/python3.11 /usr/sbin/cron

EXPOSE 80 443
CMD ["/usr/bin/supervisord"]
USER customuser
