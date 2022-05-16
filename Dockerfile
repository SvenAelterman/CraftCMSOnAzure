# use a multi-stage build for dependencies
#FROM composer:2 as vendor
# COPY composer.json composer.json
# COPY composer.lock composer.lock
# RUN composer install --ignore-platform-reqs --no-interaction --prefer-dist
# RUN composer create-project craftcms/craft --ignore-platform-reqs

FROM craftcms/nginx:8.0

USER root

#ENV SSH_PASSWD "root:Docker!"
#RUN echo "$SSH_PASSWD" | chpasswd


RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer

RUN composer create-project craftcms/craft /app --ignore-platform-reqs

COPY composer.json composer.json
COPY composer.lock composer.lock

RUN composer install --ignore-platform-reqs --no-interaction --prefer-dist

RUN chown -R www-data:www-data /app/
# the user is `www-data`, so we copy the files using the user and group
COPY --chown=www-data:www-data --from=vendor /app/vendor/ /app/vendor/
COPY --chown=www-data:www-data . .


# Modifications to run in App Service
# Install OpenSSH and set the password for root to "Docker!". 
# In this example, "apk add" is the install instruction for an Alpine Linux-based image.
#USER root
RUN apk add openssh sudo \
	&& echo "root:Docker!" | chpasswd
# Copy the sshd_config file to the /etc/ directory
COPY sshd_config /etc/ssh/
COPY start.sh /etc/start.sh
COPY BaltimoreCyberTrustRoot.crt.pem /etc/BaltimoreCyberTrustRoot.crt.pem
RUN ssh-keygen -A
RUN addgroup sudo
# This seems potentially dangerous, letting www-data run as sudo
RUN adduser www-data sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
# End modifications to run in App Service

# the user is `www-data`, so we copy the files using the user and group
USER www-data
COPY --chown=www-data:www-data --from=vendor /app/vendor/ /app/vendor/
COPY --chown=www-data:www-data . .

EXPOSE 8080 2222
ENTRYPOINT ["sh", "/etc/start.sh"]