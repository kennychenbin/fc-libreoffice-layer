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
find usr/share/fonts/ \( -name "*.ttc" -o -name "*.ttf" \) -exec cp {} "${ROOT_DIR}/layer/fonts/" \;

echo "=== 4. 提取 LibreOffice 运行时真正缺失的 NSS 库 ==="
cd "${ROOT_DIR}/workspace"

# 方法：直接从当前 Ubuntu 系统复制，版本最匹配
# 先确认系统上 libssl3.so 的实际文件名
LSS=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libssl3.so*" 2>/dev/null | head -n1)
LNSS=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libnss3.so*" 2>/dev/null | head -n1)
LNSPR=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libnspr4.so*" 2>/dev/null | head -n1)
LNSSUTIL=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libnssutil3.so*" 2>/dev/null | head -n1)
LSMIME=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libsmime3.so*" 2>/dev/null | head -n1)
LSSL=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libssl.so*" 2>/dev/null | head -n1)
LCRYPTO=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libcrypto.so*" 2>/dev/null | head -n1)
LPLC=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libplc4.so*" 2>/dev/null | head -n1)
LPLDS=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -name "libplds4.so*" 2>/dev/null | head -n1)

LAYER_LIB="${ROOT_DIR}/layer/lib"

for lib in "$LSS" "$LNSS" "$LNSPR" "$LNSSUTIL" "$LSMIME" "$LSSL" "$LCRYPTO" "$LPLC" "$LPLDS"; do
    if [ -n "$lib" ] && [ -e "$lib" ]; then
        cp -L "$lib" "$LAYER_LIB/"   # -L 参数：如果是软链接则复制实际文件
        echo "已复制: $lib"
    fi
done

# 为 libssl3.so 建立无版本号软链（soffice.bin dlopen 时用的是这个名字）
cd "$LAYER_LIB"
REAL_SSL3=$(ls libssl3.so* 2>/dev/null | grep -v '^libssl3.so$' | head -n1)
if [ -n "$REAL_SSL3" ]; then
    ln -sf "$REAL_SSL3" libssl3.so
    echo "软链接: libssl3.so -> $REAL_SSL3"
elif [ -f "libssl3.so" ]; then
    echo "libssl3.so 已存在（直接文件）"
fi

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice7.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -f *.rc *.desktop

echo "=== 6. 打包 ==="
cd "${ROOT_DIR}/layer"
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice7.4 fonts lib

echo "=== 成功完成！==="
