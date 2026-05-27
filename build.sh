#!/bin/bash
set -e

ROOT_DIR=$GITHUB_WORKSPACE
LIBREOFFICE_VERSION="7.4.7.2"
DOWNLOAD_URL="https://downloadarchive.documentfoundation.org/libreoffice/old/${LIBREOFFICE_VERSION}/deb/x86_64/LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_deb.tar.gz"

echo "=== 1. 创建工作目录 ==="
mkdir -p "${ROOT_DIR}/workspace"
mkdir -p "${ROOT_DIR}/layer/libreoffice7.4"
mkdir -p "${ROOT_DIR}/layer/fonts"
mkdir -p "${ROOT_DIR}/layer/lib"

echo "=== 2. 下载并解压 LibreOffice ==="
cd "${ROOT_DIR}/workspace"
wget -qO libreoffice.tar.gz "${DOWNLOAD_URL}"
tar -xzf libreoffice.tar.gz
DEB_DIR=$(find "${ROOT_DIR}/workspace" -type d -name "DEBS" | head -n 1)
cd "$DEB_DIR"
for deb in *.deb; do dpkg-deb -x "$deb" .; done
cp -r opt/libreoffice7.4/* "${ROOT_DIR}/layer/libreoffice7.4/"

echo "=== 3. 下载中文字体 ==="
cd "${ROOT_DIR}/workspace"
wget -qO wqy-zenhei.deb https://mirrors.ustc.edu.cn/debian/pool/main/f/fonts-wqy-zenhei/fonts-wqy-zenhei_0.9.45-8_all.deb
dpkg-deb -x wqy-zenhei.deb .
find usr/share/fonts/ -name "*.ttc" -o -name "*.ttf" -exec cp {} "${ROOT_DIR}/layer/fonts/" \;

echo "=== 4. 【核心修正】下载低版本 GLIBC 兼容的系统基础库 (Debian 10 历史快照) ==="
cd "${ROOT_DIR}/workspace"

# 绝杀改动：使用 2020 年的 Debian 10 (Buster) 快照源。
# 这里面的 libssl1.1、libnss3、libnspr4 只需要低版本的 GLIBC 2.14~2.28 即可运行，完美贴合阿里云环境！
wget -qO libssl1.1.deb https://snapshot.debian.org/archive/debian/20200101T000000Z/pool/main/o/openssl/libssl1.1_1.1.1d-0+deb10u2_amd64.deb
wget -qO libnss3.deb https://snapshot.debian.org/archive/debian/20200101T000000Z/pool/main/n/nss/libnss3_3.42.1-1+deb10u1_amd64.deb
wget -qO libnspr4.deb https://snapshot.debian.org/archive/debian/20200101T000000Z/pool/main/n/nspr/libnspr4_4.20-1_amd64.deb

# 批量解压提取
dpkg-deb -x libssl1.1.deb .
dpkg-deb -x libnss3.deb .
dpkg-deb -x libnspr4.deb .

# 提取所有的 .so 库
find usr/lib/ -name "*.so*" -exec cp -d {} "${ROOT_DIR}/layer/lib/" \;

# 💡 额外创建一个兼容软链接：因为 LibreOffice 7.4 编译时找的是 libssl3.so，
# 实际上 libssl1.1 和它 API 核心高度兼容，我们直接给 libssl.so.1.1 建立一个叫 libssl3.so 的“假身份”骗过 LibreOffice
cd "${ROOT_DIR}/layer/lib"
if [ -f "libssl.so.1.1" ]; then
    ln -s libssl.so.1.1 libssl3.so
    ln -s libcrypto.so.1.1 libcrypto3.so
fi

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice7.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -rf *.rc *.desktop

echo "=== 6. 正确打包 ==="
cd "${ROOT_DIR}/layer"
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice7.4 fonts lib
echo "=== 成功完成！ ==="
