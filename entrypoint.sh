#!/bin/bash

if [ -z "$CINDER_DBPASS" ];then
  echo "error: CINDER_DBPASS not set"
  exit 1
fi

if [ -z "$CINDER_DB" ];then
  echo "error: CINDER_DB not set"
  exit 1
fi

if [ -z "$RABBIT_HOST" ];then
  echo "error: RABBIT_HOST not set"
  exit 1
fi

if [ -z "$RABBIT_USERID" ];then
  echo "error: RABBIT_USERID not set"
  exit 1
fi

if [ -z "$RABBIT_PASSWORD" ];then
  echo "error: RABBIT_PASSWORD not set"
  exit 1
fi

if [ -z "$CINDER_PASS" ];then
  echo "error: CINDER_PASS not set"
  exit 1
fi

if [ -z "$KEYSTONE_INTERNAL_ENDPOINT" ];then
  echo "error: KEYSTONE_INTERNAL_ENDPOINT not set"
  exit 1
fi

if [ -z "$KEYSTONE_ADMIN_ENDPOINT" ];then
  echo "error: KEYSTONE_ADMIN_ENDPOINT not set"
  exit 1
fi

if [ -z "$MY_IP" ];then
  echo "error: MY_IP not set. my_ip use management interface IP address of cinder-api."
  exit 1
fi

# GLANCE_HOST = pillar['glance']['internal_endpoint']
if [ -z "$GLANCE_HOST" ];then
  echo "error: GLANCE_HOST not set."
  exit 1
fi

if [ -z "$VOLUME_BACKEND_NAME" ];then
  echo "error: VOLUME_BACKEND_NAME not set."
  exit 1
fi

if [ -z "$NFS_SERVER" ];then
  echo "error: NFS_SERVER not set."
  exit 1
fi

CRUDINI='/usr/bin/crudini'

CONNECTION=mysql://cinder:$CINDER_DBPASS@$CINDER_DB/cinder

if [ ! -f /etc/cinder/.complete ];then

    cp -rp /cinder/* /etc/cinder

    $CRUDINI --set /etc/cinder/cinder.conf database connection $CONNECTION

    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit

    $CRUDINI --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host $RABBIT_HOST
    $CRUDINI --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USERID
    $CRUDINI --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASSWORD    

    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone

    $CRUDINI --del /etc/cinder/cinder.conf keystone_authtoken

    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$KEYSTONE_INTERNAL_ENDPOINT:5000
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://$KEYSTONE_ADMIN_ENDPOINT:35357
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken project_domain_id default
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken user_domain_id default
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken project_name service
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken username cinder
    $CRUDINI --set /etc/cinder/cinder.conf keystone_authtoken password $CINDER_PASS

    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT my_ip $MY_IP

    $CRUDINI --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT state_path /var/lib/cinder

    # 设置volume
    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT enabled_backends $VOLUME_BACKEND_NAME
    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT glance_host $GLANCE_HOST
    $CRUDINI --set /etc/cinder/cinder.conf DEFAULT glance_api_version 2 # configuring multiple cinder back ends
    
    # 设置 nfs
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME nfs_mount_attempts 3
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME nfs_oversub_ratio 3.0
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME nfs_used_ratio 0.95
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME volume_backend_name $VOLUME_BACKEND_NAME
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME volume_driver cinder.volume.drivers.nfs.NfsDriver
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME nfs_shares_config /etc/cinder/nfsshares
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME nfs_sparsed_volumes True
    # cinder run_as_root = True
    $CRUDINI --set /etc/cinder/cinder.conf $VOLUME_BACKEND_NAME nas_secure_file_operations false

    echo ${NFS_SERVER}:/volume > /etc/cinder/nfsshares
    # chown root:cinder /etc/cinder/nfsshares
    # chmod 0640 /etc/cinder/nfsshares
    
    touch /etc/cinder/.complete
fi

/usr/bin/supervisord -n