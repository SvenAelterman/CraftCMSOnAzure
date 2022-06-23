# Use a multi-stage build for dependencies
# It reduces the final image size
FROM composer:latest as vendor

ARG craftversion=1.1.7

#  Could specify in composer require statement a specific version of craftcms/cms 
# instead of using composer update
RUN composer create-project craftcms/craft:$craftversion /app --no-dev --ignore-platform-req=ext-gd \
	&& composer update \
	&& composer require \
	craftcms/feed-me:4.4.3 \
	craftcms/redactor:2.10.6 \
	ether/seo:3.7.4 \
	nystudio107/craft-minify:1.2.11 \
	putyourlightson/craft-sendgrid:1.2.3 \
	putyourlightson/craft-sprig:1.12.2 \
	solspace/craft-freeform:3.13.7 \
	verbb/expanded-singles:1.2.0 \
	--ignore-platform-req=ext-gd

# TODO: Add Azure blob storage plugin

# Due to dependency hell, using latest version of PHP
FROM craftcms/nginx:8.1

USER root

# Update package list and upgrade packages
RUN apk -U upgrade

# Install mysql tools for mysqldump to be available
RUN apk add --no-cache mysql-client

#region Modifications to run in App Service

# Install OpenSSH and set the password for root to "Docker!". 
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

#endregion End modifications to run in App Service

USER www-data

# the user is `www-data`, so we copy the files using the user and group
COPY --chown=www-data:www-data --from=vendor /app/ /app/
# Coyping blank .env to bypass craft setup
COPY --chown=www-data:www-data empty.env /app/.env

# TODO: Copy UWG custom templates, files, etc. here
#COPY --chown=www-data:www-data . .

EXPOSE 8080 2222
ENTRYPOINT ["sh", "/etc/start.sh"]