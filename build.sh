#!/bin/bash
set -e

# 获取当前工作空间的绝对路径
ROOT_DIR=$GITHUB_WORKSPACE
LIBREOFFICE_VERSION="7.4.7.2"
DOWNLOAD_URL="https://downloadarchive.documentfoundation.org/libreoffice/old/${LIBREOFFICE_VERSION}/deb/x86_64/LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_deb.tar.gz"

echo "=== 1. 创建绝对路径工作目录 ==="
mkdir -p "${ROOT_DIR}/workspace"
mkdir -p "${ROOT_DIR}/layer/libreoffice7.4"
mkdir -p "${ROOT_DIR}/layer/fonts"

echo "=== 2. 下载 LibreOffice ==="
cd "${ROOT_DIR}/workspace"
wget -qO libreoffice.tar.gz "${DOWNLOAD_URL}"

echo "=== 3. 解压并提取二进制文件 ==="
tar -xzf libreoffice.tar.gz
DEB_DIR=$(find "${ROOT_DIR}/workspace" -type d -name "DEBS" | head -n 1)

cd "$DEB_DIR"
for deb in *.deb; do
    dpkg-deb -x "$deb" .
done

# 使用绝对路径进行复制，绝对不会出错
cp -r opt/libreoffice7.4/* "${ROOT_DIR}/layer/libreoffice7.4/"

echo "=== 4. 下载中文字体 ==="
cd "${ROOT_DIR}/workspace"
wget -qO wqy-zenhei.deb http://ftp.de.debian.org/debian/pool/main/f/fonts-wqy-zenhei/fonts-wqy-zenhei_0.9.45-8_all.deb
dpkg-deb -x wqy-zenhei.deb .
find usr/share/fonts/ -name "*.ttc" -o -name "*.ttf" -exec cp {} "${ROOT_DIR}/layer/fonts/" \;

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice7.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program
rm -rf *.rc *.desktop

echo "=== 6. 打包成 ZIP ==="
cd "${ROOT_DIR}/layer"
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice7.4 fonts
echo "=== 成功完成 ==="
