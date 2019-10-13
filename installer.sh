#!/bin/bash

read -p "Enter IP address of your PXE Server: " ip

#directories for syslinux files and for images
mkdir -p /srv/tftp/{images,pxelinux} 

#installing nginx, samba, tftpd-hpa
echo "deb [arch=amd64] http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -cs) nginx" >> /etc/apt/sources.list
wget http://nginx.org/keys/nginx_signing.key | sudo apt-key add -
sudo apt update && sudo apt-get install -y samba tftpd-hpa nginx

cd /tmp \
&& wget https://www.kernel.org/pub/linux/utils/boot/syslinux/4.xx/syslinux-4.02.tar.gz \
&& tar -xzf syslinux-4.02.tar.gz \
&& cd syslinux-4.02/ \
&& find ./ -name "memdisk" -type f|xargs -I {} cp '{}' /srv/tftp/ \
&& find ./ -name "gpxelinux.0"|xargs -I {} cp '{}' /srv/tftp/ \
&& find ./ -name "*.c32"|xargs -I {} cp '{}' /srv/tftp/  
rm -rf /tmp/syslinux-4.02/
chmod 766 /srv/tftp/images

#tftpd-hpa config.
sudo echo "rg \\\ /" > /etc/tftpd.remap
sudo echo -e "#/etc/default/tftpda-hpa \nTFTP_USERNAME="tftp" \nTFTP_DIRECTORY="/srv/tftp" \nTFTP_ADDRESS="0.0.0.0:69" \nTFTP_OPTIONS="--secure  -l -v -m /etc/tftpd.remap"" > /etc/default/tftpda-hpa

#samba config.
sudo echo -e "[images] \ncomment = images \npath = /srv/tftp/images \ncreate mask = 0660 \ndirectory mask = 0771 \nwritable = yes \nguest ok=yes" >> /etc/samba/smb.conf

#nginx config.
touch /etc/nginx/conf.d/pxe.conf
echo -e "server { \n\tlisten 80 default_server;\n\tlisten [::]:80 default_server;\n\tindex index.html index.htm index.nginx-debian.html;\n\tserver_name pxe.yclients.tech;\n\taccess_log /var/log/nginx/pxe.access.log;\n\terror_log /var/log/nginx/pxe.error.log;\n\tlocation / {\n\t\troot /home/images/;\n\t}\n}" >> /etc/nginx/conf.d/pxe.conf
nginx -s reload
systemctl restart nginx.service
