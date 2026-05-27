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

echo "=== 4. 用 Debian 9 容器提取兼容 NSS 库（精确匹配 GLIBC 2.24）==="
docker run --rm \
  -v "${ROOT_DIR}/layer/lib:/output" \
  debian:stretch \
  bash -c "
    # 切换为归档源（stretch 已停止维护）
    echo 'deb http://archive.debian.org/debian stretch main' > /etc/apt/sources.list
    echo 'deb http://archive.debian.org/debian-security stretch/updates main' >> /etc/apt/sources.list
    apt-get -o Acquire::Check-Valid-Until=false update -qq

    # 安装 LibreOffice 7.4 所需的 NSS 相关库
    apt-get install -y --no-install-recommends \
      libnss3 \
      libnspr4 \
      libssl1.0.2 \
      libglib2.0-0 2>/dev/null

    # 复制所有相关 .so 文件（-L 跟随软链接复制实际文件）
    find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu \
      \( -name 'libssl3.so*' \
      -o -name 'libnss3.so*' \
      -o -name 'libnssutil3.so*' \
      -o -name 'libnspr4.so*' \
      -o -name 'libsmime3.so*' \
      -o -name 'libplc4.so*' \
      -o -name 'libplds4.so*' \
      -o -name 'libssl.so*' \
      -o -name 'libssl1.0.so*' \
      -o -name 'libcrypto.so*' \
      \) -exec cp -L {} /output/ \; 2>/dev/null || true

    # 建立 soffice.bin 动态链接器查找用的标准名软链
    cd /output
    # libssl3.so（NSS 的 SSL 库，不是 OpenSSL）
    REAL=\$(ls libnss3.so* 2>/dev/null | head -1)
    [ -n \"\$REAL\" ] && ln -sf \"\$REAL\" libnss3.so && echo \"软链: libnss3.so -> \$REAL\"

    # libssl3.so 在 Debian 9 里实际叫 libssl3.so（由 libnss3 包提供）
    REAL=\$(ls libssl3.so* 2>/dev/null | grep -v '^libssl3.so$' | head -1)
    [ -n \"\$REAL\" ] && ln -sf \"\$REAL\" libssl3.so && echo \"软链: libssl3.so -> \$REAL\"
    # 如果 libssl3.so 就是实际文件名则跳过

    REAL=\$(ls libnspr4.so* 2>/dev/null | grep -v '^libnspr4.so$' | head -1)
    [ -n \"\$REAL\" ] && ln -sf \"\$REAL\" libnspr4.so && echo \"软链: libnspr4.so -> \$REAL\"

    REAL=\$(ls libnssutil3.so* 2>/dev/null | grep -v '^libnssutil3.so$' | head -1)
    [ -n \"\$REAL\" ] && ln -sf \"\$REAL\" libnssutil3.so && echo \"软链: libnssutil3.so -> \$REAL\"

    echo '--- 提取完成，库文件列表 ---'
    ls -la /output
  "

echo "=== 5. 精简体积 ==="
cd "${ROOT_DIR}/layer/libreoffice7.4"
rm -rf readmes/ LICENSE README CHANGELOG
cd program && rm -f *.rc *.desktop

echo "=== 6. 打包 ==="
cd "${ROOT_DIR}/layer"
zip -r9 "${ROOT_DIR}/libreoffice_layer.zip" libreoffice7.4 fonts lib

echo "=== 成功完成！==="
