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

# volumes:
- /etc/cinder/: /etc/cinder

# 启动cinder-volume
```bash
docker run -d --name cinder-volume \
    -v /opt/openstack/cinder-volume/:/etc/cinder \
    -v /opt/openstack/log/cinder-volume/:/var/log/cinder/ \
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
    10.64.0.50:5000/lzh/cinder-api:kilo
```

# 配置cinder ceph 后端
## 在cinder-volume, nova-compute节点上安装ceph client
```bash
apt-get -t jessie-backports  install ceph-common
```
## 在ceph节点上执行下面的命令, 创建pool
```bash
ceph osd pool create volumes 128
ceph osd pool create images 128
ceph osd pool create backups 128
ceph osd pool create vms 128
```
## 在ceph节点上执行下面的命令, 创建 cephx authentication
```bash
ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images'
ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups'
```
## 从ceph节点上复制ceph.conf到cinder-volume, nova-compute节点
```bash
scp /etc/ceph/ceph.conf root@{your-volume-server}:/etc/ceph
ceph auth get-or-create client.cinder | ssh {your-volume-server} \
     sudo tee /etc/ceph/ceph.client.cinder.keyring

ssh root@{your-cinder-volume-server} chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring

ceph auth get-or-create client.cinder | ssh {your-nova-compute-server} \
     sudo tee /etc/ceph/ceph.client.cinder.keyring
```

## 为nova-compute上的libvirt添加ceph auth
### 在ceph节点上执行下面的命令，创建一个临时key文件
```bash
ceph auth get-key client.cinder | ssh {your-compute-node} tee /tmp/client.cinder.key
```
### 在所有nova-compute节点上执行下面命令，添加secret key 到 libvirt
```bash
uuidgen
297bccc9-0ee3-4400-856f-c8a940ffb1cc

cat > /tmp/secret.xml <<EOF
<secret ephemeral='no' private='no'>
  <uuid>297bccc9-0ee3-4400-856f-c8a940ffb1cc</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF
virsh secret-define --file /tmp/secret.xml
Secret 297bccc9-0ee3-4400-856f-c8a940ffb1cc created
virsh secret-set-value --secret 297bccc9-0ee3-4400-856f-c8a940ffb1cc \
      --base64 $(cat /tmp/client.cinder.key) && rm /tmp/client.cinder.key secret.xml
```
## 配置ceph后端
```bash
[DEFAULT]
...
enabled_backends = ceph-volume

[ceph-volume]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
rbd_pool = volumes
volume_backend_name = ceph-volume
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_flatten_volume_from_snapshot = false
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_user = cinder
rbd_secret_uuid = 297bccc9-0ee3-4400-856f-c8a940ffb1cc  # 通过virsh secret-list  
```
## 重启cinder-volume
```bash
service cinder-volume restart
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

cinder --os-username admin --os-tenant-name admin  --os-volume-api-version 2 type-create ceph
cinder --os-username admin --os-tenant-name admin  --os-volume-api-version 2 \
       type-key ceph set volume_backend_name=ceph-volume
cinder --os-username admin --os-tenant-name admin  --os-volume-api-version 2 extra-specs-list
```

# 配置cinder-backup
## 在ceph节点上执行下面的命令
```bash
ceph auth get-or-create client.cinder-backup | ssh {your-cinder-volume-server} sudo tee /etc/ceph/ceph.client.cinder-backup.keyring
ssh {your-cinder-volume-server} sudo chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring
```
## 在cinder-volume节点安装cinder-backup
```bash
apt-get -t jessie-backports install cinder-backup -y
```
## 编辑/etc/cinder/cinder.conf
```bash
backup_driver = cinder.backup.drivers.ceph
backup_ceph_conf = /etc/ceph/ceph.conf
backup_ceph_user = cinder-backup
backup_ceph_chunk_size = 134217728
backup_ceph_pool = backups
backup_ceph_stripe_unit = 0
backup_ceph_stripe_count = 0
restore_discard_excess_bytes = true
```
## 重启cinder-backup
```bash
service cinder-backup restart
```