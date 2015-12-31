# 环境变量
- CINDER_DB: cinder数据库ip
- CINDER_DBPASS: cinder数据库密码
- RABBIT_HOST: rabbitmq IP
- RABBIT_USERID: rabbitmq user
- RABBIT_PASSWORD: rabbitmq user 的 password
- KEYSTONE_INTERNAL_ENDPOINT: keystone internal endpoint
- KEYSTONE_ADMIN_ENDPOINT: keystone admin endpoint
- CINDER_PASS: openstack cinder用户密码
- MY_IP: my_ip
- GLANCE_HOST: glance internal endpoint
- VOLUME_BACKEND_NAME: volume_backend_name
- NFS_SERVER: nfs server ip address

# volumes:
- /etc/cinder/: /etc/cinder

# 启动cinder-volume-nfs
```bash
docker run -d --name cinder-volume-nfs \
    -v /etc/cinder/:/etc/cinder \
    -e CINDER_DB=10.64.0.52 \
    -e CINDER_DBPASS=cinder_dbpass \
    -e RABBIT_HOST=10.64.0.52 \
    -e RABBIT_USERID=openstack \
    -e RABBIT_PASSWORD=openstack \
    -e KEYSTONE_INTERNAL_ENDPOINT=10.64.0.52 \
    -e KEYSTONE_ADMIN_ENDPOINT=10.64.0.52 \
    -e CINDER_PASS=cinder \
    -e MY_IP=10.64.0.52 \
    -e GLANCE_HOST=10.64.0.52 \
    -e VOLUME_BACKEND_NAME=one \
    -e NFS_SERVER=nfs_server_ip
    10.64.0.50:5000/lzh/cinder-volume-nfs:kilo
```

# 配置cinder nfs 后端
## 在cinder-volume-nfs, nova-compute节点上安装nfs client
### jessie,trusty
```bash
apt-get install nfs-common
```
### centos
```bash
yum install nfs-utils
```

# 在nfs 节点上安装nfs server
```bash
apt-get install nfs-kernel-server
chown -R cinder:cinder /volume
cat /etc/exports 
# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/volume *(rw,sync,insecure,no_all_squash,no_subtree_check,no_root_squash)
# /volume *(rw,async,insecure,no_all_squash,no_subtree_check,no_root_squash)
```

# 使用多后端cinder
```bash
cat <<EOF>>admin-openrc.sh 
#export OS_TENANT_NAME=admin
export OS_IDENTITY_API_VERSION=3
export OS_USERNAME=admin
export OS_PASSWORD=123456
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_PROJECT_DOMAIN_ID=default
#export OS_TENANT_ID=admin
export OS_AUTH_URL=http://10.64.0.52:35357/v3
EOF

source admin-rc.sh

cinder --os-username admin --os-tenant-name admin  --os-volume-api-version 2 type-create one
cinder --os-username admin --os-tenant-name admin  --os-volume-api-version 2 \
       type-key one set volume_backend_name=one
cinder --os-username admin --os-tenant-name admin  --os-volume-api-version 2 extra-specs-list
```