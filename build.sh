#!/bin/bash
set -e

ROOT_DIR=$GITHUB_WORKSPACE
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
cp -r opt/libreoffice6.4/* "${ROOT_DIR}/layer/libreoffice6.4/"

echo "=== 3. 抓取开源中文字体 ==="
cd "${ROOT_DIR}/workspace"
wget -qO wqy-zenhei.deb https://mirrors.ustc.edu.cn/debian/pool/main/f/fonts-wqy-zenhei/fonts-wqy-zenhei_0.9.45-8_all.deb
dpkg-deb -x wqy-zenhei.deb .
# 💡 顺便修复开源字体这里的括号逻辑
find usr/share/fonts/ \( -iname "*.ttc" -o -iname "*.ttf" \) -exec cp {} "${ROOT_DIR}/layer/fonts/" \;

echo "=== 4. 【核心修复】安全注入本地 Windows 专属字体 ==="
if [ -d "${ROOT_DIR}/win_fonts" ]; then
    echo "发现 win_fonts 文件夹，正在全量合并压入层..."
    # 💡 绝杀：使用 -iname 完美兼容大写 .TTF，并用 \( \) 包裹保证不管是 ttc 还是 ttf 都会被 cp 复制
    find "${ROOT_DIR}/win_fonts" \( -iname "*.ttc" -o -iname "*.ttf" \) -exec cp {} "${ROOT_DIR}/layer/fonts/" \;
else
    echo "🚨 错误：未检测到 win_fonts 文件夹！"
fi

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice6.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -rf *.rc *.desktop

echo "=== 6. 正确打包 ==="
cd "${ROOT_DIR}/layer"
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice6.4 fonts
echo "=== 包含全量大写/小写 Windows 字体的全新层打包成功！ ==="
