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

echo "=== 4. 用 Debian 10 容器提取 NSS 3.42 库 ==="
docker run --rm \
  -v "${ROOT_DIR}/layer/lib:/output" \
  debian:buster \
  bash -c "
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      libnss3 \
      libnspr4 \
      libssl1.1 2>/dev/null

    # 复制所有相关库（-L 跟随软链接复制实际文件）
    find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu \
      \( -name 'libssl3.so*' \
      -o -name 'libnss3.so*' \
      -o -name 'libnssutil3.so*' \
      -o -name 'libnspr4.so*' \
      -o -name 'libsmime3.so*' \
      -o -name 'libplc4.so*' \
      -o -name 'libplds4.so*' \
      -o -name 'libssl.so*' \
      -o -name 'libcrypto.so*' \
      \) -exec cp -L {} /output/ \; 2>/dev/null || true

    # 建立标准名软链
    cd /output
    for SONAME in libnss3.so libnssutil3.so libnspr4.so libsmime3.so libplc4.so libplds4.so; do
      REAL=\$(ls \${SONAME}.* 2>/dev/null | head -1)
      if [ -n \"\$REAL\" ] && [ ! -f \"\$SONAME\" ]; then
        ln -sf \"\$REAL\" \"\$SONAME\"
        echo \"软链: \$SONAME -> \$REAL\"
      fi
    done

    # libssl3.so 由 libnss3 包提供（NSS 体系，非 OpenSSL）
    if [ ! -f libssl3.so ]; then
      REAL=\$(ls libnss3.so.* 2>/dev/null | head -1)
      [ -n \"\$REAL\" ] && ln -sf \"\$REAL\" libssl3.so && echo \"软链: libssl3.so -> \$REAL\"
    fi

    # 验证 NSS 符号版本（日志里应看到 NSS_3.34 以上）
    echo '--- NSS 符号版本验证 ---'
    objdump -p /output/libnss3.so | grep 'NSS_3\.' || true

    echo '--- 最终库文件列表 ---'
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
