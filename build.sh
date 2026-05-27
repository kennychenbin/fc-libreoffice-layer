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
# 换成中科大稳定镜像源，下载开源中文字体
wget -qO wqy-zenhei.deb https://mirrors.ustc.edu.cn/debian/pool/main/f/fonts-wqy-zenhei/fonts-wqy-zenhei_0.9.45-8_all.deb
dpkg-deb -x wqy-zenhei.deb .
find usr/share/fonts/ -name "*.ttc" -o -name "*.ttf" -exec cp {} "${ROOT_DIR}/layer/fonts/" \;

echo "=== 4. 【核心升级】利用系统 apt 下载并提取 libssl3 和 libnss3 ==="
cd "${ROOT_DIR}/workspace"

# 关键改动：利用 Ubuntu 系统自带的 apt-get 命令直接下载最新安全的依赖包
sudo apt-get update && sudo apt-get download -y libssl3 libnss3

# 解压刚刚下载下来的系统 deb 包
for sdeb in *.deb; do
    dpkg-deb -x "$sdeb" .
done

# 将提取出来的 .so 动态链接库全部复制到层的 lib 目录中
find usr/lib/ -name "*.so*" -exec cp -d {} "${ROOT_DIR}/layer/lib/" \;

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice7.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -rf *.rc *.desktop

echo "=== 6. 正确打包 ==="
cd "${ROOT_DIR}/layer"
# 将编译好的二进制、中文字体、系统动态库一起打包
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice7.4 fonts lib
echo "=== 成功完成！ ==="
