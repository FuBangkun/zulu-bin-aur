#!/bin/bash

JAVA_VERSIONS=(8 11 17 21 25)

for JAVA_VERSION in "${JAVA_VERSIONS[@]}"; do
    echo "========================================"
    echo "正在处理 Zulu ${JAVA_VERSION} ..."
    echo "========================================"

    PKGBUILD_DIR="$(cd "$(dirname "$0")" && pwd)/zulu-${JAVA_VERSION}-bin"
    if [ ! -d "$PKGBUILD_DIR" ]; then
        echo "错误: 目录 $PKGBUILD_DIR 不存在"
        continue
    fi

    cd "$PKGBUILD_DIR"

    if [ -n "$(ls zulu*-ca-jdk*-linux_x64.tar.gz 2>/dev/null)" ]; then
        rm -f zulu*-ca-jdk*-linux_x64.tar.gz
        echo "Zulu ${JAVA_VERSION} 的 x86_64 文件已删除"
    fi
    if [ -n "$(ls zulu*-ca-jdk*-linux_aarch64.tar.gz 2>/dev/null)" ]; then
        rm -f zulu*-ca-jdk*-linux_aarch64.tar.gz
        echo "Zulu ${JAVA_VERSION} 的 aarch64 文件已删除"
    fi

    echo "Zulu ${JAVA_VERSION} 处理完成!"
    echo ""
    cd ..
done

echo "========================================"
echo "所有版本处理完毕!"