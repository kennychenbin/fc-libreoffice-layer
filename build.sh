#!/bin/bash
set -e

LIBREOFFICE_VERSION="7.4.7.2"
# 换成清华大学镜像源，防止海外网络超时
DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/libreoffice/libreoffice/stable/${LIBREOFFICE_VERSION}/deb/x86_64/LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_deb.tar.gz"

echo "=== 1. 创建工作目录 ==="
mkdir -p workspace
mkdir -p layer/libreoffice7.4
mkdir -p layer/fonts
cd workspace

echo "=== 2. 下载 LibreOffice ==="
wget -qO libreoffice.tar.gz "${DOWNLOAD_URL}"

echo "=== 3. 解压并提取二进制文件 ==="
tar -xzf libreoffice.tar.gz
DEB_DIR=$(find . -maxdepth 2 -type d -name "DEBS")
cd "$DEB_DIR"
for deb in *.deb; do
    dpkg-deb -x "$deb" .
done
cp -r opt/libreoffice7.4/* ../../layer/libreoffice7.4/
cd ../../

echo "=== 4. 下载中文字体 ==="
cd workspace
wget -qO wqy-zenhei.deb http://ftp.de.debian.org/debian/pool/main/f/fonts-wqy-zenhei/fonts-wqy-zenhei_0.9.45-8_all.deb
dpkg-deb -x wqy-zenhei.deb .
find usr/share/fonts/ -name "*.ttc" -o -name "*.ttf" -exec cp {} ../layer/fonts/ \;

echo "=== 5. 精简体积 ==="
cd ../layer/libreoffice7.4
rm -rf readmes/ LICENSE README CHANGELOG
cd program
rm -rf *.rc *.desktop

echo "=== 6. 打包成 ZIP ==="
cd ../../layer
zip -r9 ../libreoffice_layer.zip libreoffice7.4 fonts
echo "=== 完成 ==="
