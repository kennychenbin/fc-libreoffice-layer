#!/bin/bash
set -e

ROOT_DIR=$GITHUB_WORKSPACE
# 换成完美兼容低版本 GLIBC 的官方长期稳定版 6.4.7
LIBREOFFICE_VERSION="6.4.7.2"
DOWNLOAD_URL="https://downloadarchive.documentfoundation.org/libreoffice/old/${LIBREOFFICE_VERSION}/deb/x86_64/LibreOffice_${LIBREOFFICE_VERSION}_Linux_x86-64_deb.tar.gz"

echo "=== 1. 创建工作目录 ==="
mkdir -p "${ROOT_DIR}/workspace"
mkdir -p "${ROOT_DIR}/layer/libreoffice6.4"
mkdir -p "${ROOT_DIR}/layer/fonts"

echo "=== 2. 下载并解压 LibreOffice 6.4 ==="
cd "${ROOT_DIR}/workspace"
wget -qO libreoffice.tar.gz "${DOWNLOAD_URL}"
tar -xzf libreoffice.tar.gz
DEB_DIR=$(find "${ROOT_DIR}/workspace" -type d -name "DEBS" | head -n 1)
cd "$DEB_DIR"
for deb in *.deb; do dpkg-deb -x "$deb" .; done
# 注意：6.4 版本的解压路径是 opt/libreoffice6.4
cp -r opt/libreoffice6.4/* "${ROOT_DIR}/layer/libreoffice6.4/"

echo "=== 3. 下载中文字体 ==="
cd "${ROOT_DIR}/workspace"
wget -qO wqy-zenhei.deb https://mirrors.ustc.edu.cn/debian/pool/main/f/fonts-wqy-zenhei/fonts-wqy-zenhei_0.9.45-8_all.deb
dpkg-deb -x wqy-zenhei.deb .
find usr/share/fonts/ -name "*.ttc" -o -name "*.ttf" -exec cp {} "${ROOT_DIR}/layer/fonts/" \;

echo "=== 4. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice6.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -rf *.rc *.desktop

echo "=== 5. 正确打包 ==="
cd "${ROOT_DIR}/layer"
# 纯净打包：彻底抛弃那些冲突的系统动态库（lib文件夹），只留本体和字体
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice6.4 fonts
echo "=== 成功完成！ ==="
