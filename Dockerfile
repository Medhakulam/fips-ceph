FROM redhat/ubi8
USER root
EXPOSE 6789 6800 6801 6802 6803 6804 6805 80 5000 8443 9283
RUN update-crypto-policies --set FIPS
RUN \
    dnf update -y --setopt=install_weak_deps=0 --nodocs && \
    dnf install -y gcc gcc-c++ git vim cmake ninja-build python3-pip && \

    dnf install -y --setopt=install_weak_deps=0 --nodocs wget unzip util-linux python3-setuptools udev device-mapper && \
    dnf install -y ca-certificates kmod lvm2 systemd-udev sg3_utils procps-ng hostname udev libibverbs sqlite-devel && \
    yum --nogpgcheck --repofrompath=centos,http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/ install -y libibverbs-utils libibverbs-devel libudev-devel libblkid-devel libaio-devel libcap-ng-devel libicu-devel keyutils keyutils-libs-devel openldap-devel fuse-libs cryptsetup-luks snappy && \
    dnf -y --setopt=install_weak_deps=False --setopt=tsflags=nodocs install       http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/centos-gpg-keys-8-6.el8.noarch.rpm       http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/centos-stream-repos-8-6.el8.noarch.rpm  && dnf -y --setopt=install_weak_deps=False --setopt=tsflags=nodocs install epel-release && \
    dnf -y --setopt=install_weak_deps=False --setopt=tsflags=nodocs install epel-release && \
    dnf config-manager --set-enabled powertools && \
    yum install -y snappy-devel lz4-devel curl-devel libbabeltrace-devel lua-devel libnl3-devel thrift-devel gperf librabbitmq-devel librdkafka-devel fuse-devel cryptsetup-devel re2-devel liboath-devel && \
    yum install -y openssl-devel expat-devel python36-devel lttng-ust-devel
RUN mkdir /root/legacy
ADD legacy/* /root/legacy/.
ADD setup.py /root/setup.py
ADD test_rbd.py /root/test_rbd.py
RUN mkdir -p /usr/lib64/rados-classes
WORKDIR /
RUN git clone https://github.com/ceph/ceph.git \
    && cd ceph/ \
    && git checkout -b v17.2.6 tags/v17.2.6 && \
    pip3 install sphinx pyyaml && \
    pip3 install cython==3.0.0 && \
    cp /root/setup.py /ceph/src/pybind/rbd/setup.py && \
    cp /root/test_rbd.py /ceph/src/test/pybind/test_rbd.py && \
    sed -i 's/CMAKE_INSTALL_LIBDIR/CMAKE_INSTALL_FULL_LIBDIR/g' /ceph/src/common/options/osd.yaml.in && \
    sed -i 's/) with gil/) noexcept with gil/g' /ceph/src/pybind/rbd/rbd.pyx && \ 
    cd /ceph && \
    ./do_cmake.sh && \
    cp /root/legacy/* ./build/include/. && \
    rm -rf /root/legacy && \
    cd /ceph/build && \
    ninja -j 3 && \
    ninja src/ceph-volume/install && \
    ninja src/pybind/mgr/install && \
    shopt -s extglob && \
    find bin -type f -iregex '.*test.*' -delete && \
    find bin -type f -not \( -name 'ceph' -or -name 'init-ceph' -or -name 'ceph-debugpack' -or -name 'ceph-coverage' -or -name 'ceph-crash' -or -name 'ceph-post-file' \) -print0 | xargs -0 -I {} strip {} && \
    find lib -type f -not -path "lib/cython_modules" -print0 | xargs -0 -I {} strip {} && \
    cp -r bin/* /usr/bin/. && \
    rm -rf lib/*.a && \
    cp -r lib/libcls* /usr/lib64/rados-classes/. && \
    rm -rf lib/libcls* && \
    cp -r lib/* /usr/lib64/. && \
    cd ../../ && \
    rm -rf ceph/src/pybind/mgr && \
    cp -r ceph/src/pybind/* /usr/lib/python3.6/site-packages/. && \
    cp ceph/src/cephadm/cephadm /usr/sbin/. && \
    cp -r ceph/share/* /usr/local/share/ceph/. && \
    cp ceph/src/mount.fuse.ceph /sbin/. && \
    cp ceph/src/rbdmap /usr/bin/rbdmap && \
    find ceph/src/include/rados -maxdepth 1 -type l -delete && \
    cp -r ceph/src/include/rados /usr/include/rados && \
    cp -r ceph/src/include/buffer.h /usr/include/rados/. && \
    cp -r ceph/src/include/buffer_fwd.h /usr/include/rados/. && \
    cp -r ceph/src/include/crc32c.h /usr/include/rados/. && \
    cp -r ceph/src/include/inline_memory.h /usr/include/rados/. && \
    cp -r ceph/src/include/page.h /usr/include/rados/. && \
    cp -r ceph/src/include/rbd /usr/include/rbd && \
    cp -r ceph/src/include/cephfs /usr/include/cephfs && \
    rm -rf ceph
WORKDIR /
RUN mkdir -p /etc/ceph
ADD rbdmap /etc/ceph/.
RUN cp -r /usr/lib64/rados-classes /usr/local/lib64/.
RUN cp -r /usr/local/lib/python3.6/site-packages/ceph-1.0.0-py3.6.egg/ceph /usr/lib/python3.6/site-packages/. \
    && rm -rf /usr/local/lib/python3.6/site-packages/ceph-1.0.0-py3.6.egg/ceph
RUN cp -r /usr/local/lib/python3.6/site-packages/ceph_volume-1.0.0-py3.6.egg/ceph_volume /usr/lib/python3.6/site-packages/. \
    && rm -rf /usr/local/lib/python3.6/site-packages/ceph_volume-1.0.0-py3.6.egg/ceph_volume
RUN cp -r /usr/lib64/cython_modules/lib.3/* /usr/lib/python3.6/site-packages/. \
    && rm -rf /usr/lib64/cython_modules/lib.3/*
RUN pip3 install typing-extensions==3.7.4.3
RUN pip3 install cherrypy
RUN cp -r /usr/local/lib64/python3.6/site-packages/cherrypy /usr/lib64/python3.6/site-packages/.
RUN dnf install -y python3-pecan python3-natsort python3-routes python3-bcrypt python3-jsonpatch python3-jwt python3-dateutil python3-werkzeug python3-scipy
RUN pip3 install --upgrade pip
RUN pip3 install pyOpenSSL
RUN mkdir -p /usr/local/lib64/ceph
RUN mkdir -p /usr/local/lib64/ceph/erasure-code
RUN mkdir -p /usr/local/lib64/ceph/compressor
RUN mkdir -p /usr/local/lib64/ceph/crypto
RUN mkdir -p /usr/local/lib64/ceph/denc
RUN mkdir -p /usr/local/lib64/ceph/librbd
RUN mv /usr/lib64/libec_* /usr/local/lib64/ceph/erasure-code/. 
RUN mv /usr/lib64/libceph_lz4* /usr/local/lib64/ceph/compressor/.
RUN mv /usr/lib64/libceph_snappy* /usr/local/lib64/ceph/compressor/.
RUN mv /usr/lib64/libceph_zlib* /usr/local/lib64/ceph/compressor/.
RUN mv /usr/lib64/libceph_zstd* /usr/local/lib64/ceph/compressor/.
RUN mv /usr/lib64/libceph_crypto* /usr/local/lib64/ceph/crypto/.
RUN mv /usr/lib64/denc* /usr/local/lib64/ceph/denc/.
RUN mv /usr/lib64/libceph_librbd* /usr/local/lib64/ceph/librbd/.
RUN pip3 install prettytable
RUN groupadd -g 167 ceph && useradd -u 167 -g ceph ceph
RUN groupadd -g 993 cephadm && useradd -u 993 -g cephadm cephadm
RUN groupadd -g 992 libstoragemgmt && useradd -u 992 -g libstoragemgmt libstoragemgmt
RUN groupadd -g 991 ganesha && useradd -u 991 -g ganesha ganesha
RUN groupadd -g 32 rpc && useradd -u 32 -g rpc rpc
RUN mkdir -p /var/lib/ceph
RUN mkdir -p /var/lib/cephadm
WORKDIR /var/lib/ceph
RUN mkdir {mon,mgr,osd,mds,bootstrap-mds,bootstrap-osd,bootstrap-rbd-mirror,crash,tmp,bootstrap-mgr,bootstrap-rbd,bootstrap-rgw,radosgw}
WORKDIR /
RUN chown -R ceph:ceph /var/lib/ceph
RUN chown -R cephadm:cephadm /var/lib/cephadm
RUN mkdir -p /run/ceph
RUN mkdir -p /usr/local/share/ceph/mgr
RUN yum install -y logrotate
ADD ceph-log /etc/logrotate.d/ceph
RUN yum install -y nfs-utils
RUN cp /usr/bin/mount.ceph /sbin/mount.ceph
RUN \
     if [ -f /usr/bin/ceph-dencoder ]; then gzip -9 /usr/bin/ceph-dencoder; fi && \
    rm -f /usr/bin/ceph-dencoder
