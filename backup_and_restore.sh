#!/bin/bash
echo "Running BACKUP ALL APP's.";

#STOP ALL APP's
cd /app/CommunityServer/
docker-compose stop

#BACKUP SNAP-VERSION 
nextcloud.export
tar cvpzf /backups/snap/backup_snap_$(date +%Y%m%d-%H.%M.%S).tgz /var/snap/nextcloud/common/backups/*
rm -rf /var/snap/nextcloud/common/backups/*

#BACKUP DOCKER-APP's
cd /app
tar cvpzf /backups/app/backup_app_$(date +%Y%m%d-%H.%M.%S).tgz ./
#rsync -arvh --progress /app/ /backups/app/app.bkp.$(date +%Y%m%d-%H.%M.%S)

#START ALL APP's
cd /app/CommunityServer/
docker-compose start
echo "FINISH!";
