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

echo "=== 4. 【核心升级】在线下载所有缺少的系统基础库 (包含 libssl3, libnss3, libnspr4) ==="
cd "${ROOT_DIR}/workspace"

# 引入 libnspr4 解决缺失 libplds4.so 的问题
wget -qO libssl3.deb https://snapshot.debian.org/archive/debian/20231001T000000Z/pool/main/o/openssl/libssl3_3.0.11-1~deb12u1_amd64.deb
wget -qO libnss3.deb https://snapshot.debian.org/archive/debian/20231001T000000Z/pool/main/n/nss/libnss3_3.87.1-1_amd64.deb
wget -qO libnspr4.deb https://snapshot.debian.org/archive/debian/20231001T000000Z/pool/main/n/nspr/libnspr4_4.35-1_amd64.deb

# 批量解压提取
dpkg-deb -x libssl3.deb .
dpkg-deb -x libnss3.deb .
dpkg-deb -x libnspr4.deb .

# 把所有提取出的 .so 库全部捞到层的 lib 目录中
find usr/lib/ -name "*.so*" -exec cp -d {} "${ROOT_DIR}/layer/lib/" \;

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice7.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -rf *.rc *.desktop

echo "=== 6. 正确打包 ==="
cd "${ROOT_DIR}/layer"
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice7.4 fonts lib
echo "=== 成功完成！ ==="
