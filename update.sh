#!/bin/bash

JAVA_VERSIONS=(8 11 17 21 25)

for JAVA_VERSION in "${JAVA_VERSIONS[@]}"; do
    echo "========================================"
    echo "正在处理 Zulu ${JAVA_VERSION} ..."
    echo "========================================"
    
    API_URL="https://api.azul.com/metadata/v1/zulu/packages/?java_version=${JAVA_VERSION}&latest=true"

    echo "正在获取 Zulu ${JAVA_VERSION} 的包信息..."

    # 获取 API 响应
    response=$(curl -s "$API_URL")

    # 检查是否成功获取数据
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "错误: 无法从 API 获取 Zulu ${JAVA_VERSION} 的数据"
        continue
    fi

    # 检查响应是否为有效的 JSON 数组
    if ! echo "$response" | jq -e '. | type == "array" and length > 0' > /dev/null 2>&1; then
        echo "错误: API 返回的 Zulu ${JAVA_VERSION} 数据格式不正确或没有找到对应的包"
        continue
    fi

    # 提取第一个包的信息
    first_package=$(echo "$response" | jq '.[0]')

    read -r distro java <<< $(echo "$first_package" | jq -r '[([.distro_version[0], .distro_version[1], .distro_version[2]] | join(".")),(.java_version | join("."))]|@tsv')

    distro=$(echo "$distro" | cut -d'.' -f1-3)

    if [ "$JAVA_VERSION" = "8" ]; then
        distro=$(echo "$first_package" | jq -r '.distro_version | join(".")')
    fi

    echo "Zulu版本为$distro"
    echo "Java版本为$java"

    # 构建下载 URL
    download_url_x86_64="https://cdn.azul.com/zulu/bin/zulu${distro}-ca-jdk${java}-linux_x64.tar.gz"
    download_url_aarch64="https://cdn.azul.com/zulu/bin/zulu${distro}-ca-jdk${java}-linux_aarch64.tar.gz"

    # 检查目标目录是否存在
    PKGBUILD_DIR="$(cd "$(dirname "$0")" && pwd)/zulu-${JAVA_VERSION}-bin"
    if [ ! -d "$PKGBUILD_DIR" ]; then
        echo "错误: 目录 $PKGBUILD_DIR 不存在"
        continue
    fi

    PKGBUILD_FILE="$PKGBUILD_DIR/PKGBUILD"
    SRCINFO_FILE="$PKGBUILD_DIR/.SRCINFO"

    # 检查文件是否存在
    if [ ! -f "$PKGBUILD_FILE" ]; then
        echo "错误: $PKGBUILD_FILE 不存在"
        continue
    fi

    if [ ! -f "$SRCINFO_FILE" ]; then
        echo "错误: $SRCINFO_FILE 不存在"
        continue
    fi

    cd "$PKGBUILD_DIR"

    # 下载 x86_64 文件
    x86_64_file="zulu${distro}-ca-jdk${java}-linux_x64.tar.gz"
    if [ -f "$x86_64_file" ]; then
        echo "x86_64 文件已存在，跳过下载"
        sha256_x86_64=$(sha256sum "$x86_64_file" | cut -d' ' -f1)
        echo "SHA256: $sha256_x86_64"
    else
        # 删除旧的 x86_64 文件
        old_x86_64_files=$(ls zulu*-ca-jdk*-linux_x64.tar.gz 2>/dev/null)
        if [ -n "$old_x86_64_files" ]; then
            echo "发现旧的 x86_64 文件，正在删除..."
            rm -f zulu*-ca-jdk*-linux_x64.tar.gz
            echo "旧的 x86_64 文件已删除"
        fi
        
        echo "下载 x86_64 版本：$download_url_x86_64"

        curl -s -O "$download_url_x86_64"
        if [ -f "$x86_64_file" ]; then
            sha256_x86_64=$(sha256sum "$x86_64_file" | cut -d' ' -f1)
            echo "SHA256: $sha256_x86_64"
        else
            echo "错误: 无法下载 x86_64 文件"
            sha256_x86_64=""
        fi
    fi

    # 下载 aarch64 文件
    aarch64_file="zulu${distro}-ca-jdk${java}-linux_aarch64.tar.gz"
    if [ -f "$aarch64_file" ]; then
        echo "aarch64 文件已存在，跳过下载"
        sha256_aarch64=$(sha256sum "$aarch64_file" | cut -d' ' -f1)
        echo "SHA256: $sha256_aarch64"
    else
        # 删除旧的 aarch64 文件
        old_aarch64_files=$(ls zulu*-ca-jdk*-linux_aarch64.tar.gz 2>/dev/null)
        if [ -n "$old_aarch64_files" ]; then
            echo "发现旧的 aarch64 文件，正在删除..."
            rm -f zulu*-ca-jdk*-linux_aarch64.tar.gz
            echo "旧的 aarch64 文件已删除"
        fi

        echo "下载 aarch64 版本：$download_url_aarch64"
        
        curl -s -O "$download_url_aarch64"
        if [ -f "$aarch64_file" ]; then
            sha256_aarch64=$(sha256sum "$aarch64_file" | cut -d' ' -f1)
            echo "SHA256: $sha256_aarch64"
        else
            echo "错误: 无法下载 aarch64 文件"
            sha256_aarch64=""
        fi
    fi

    echo "更新 PKGBUILD 文件..."
    sed -i "s|_zulu_build=.*|_zulu_build=\"${distro}-ca\"|" "$PKGBUILD_FILE"
    sed -i "s|pkgver=.*|pkgver=\"${java}\"|" "$PKGBUILD_FILE"
    escaped_url_aarch64=$(echo "$download_url_aarch64" | sed 's/[\&/]/\\&/g')
    sed -i "s|source_aarch64=(\".*\")|source_aarch64=(\"$escaped_url_aarch64\")|" "$PKGBUILD_FILE"
    sed -i "s|sha256sums_aarch64=('.*')|sha256sums_aarch64=('$sha256_aarch64')|" "$PKGBUILD_FILE"
    escaped_url_x86_64=$(echo "$download_url_x86_64" | sed 's/[\&/]/\\&/g')
    sed -i "s|source_x86_64=(\".*\")|source_x86_64=(\"$escaped_url_x86_64\")|" "$PKGBUILD_FILE"
    sed -i "s|sha256sums_x86_64=('.*')|sha256sums_x86_64=('$sha256_x86_64')|" "$PKGBUILD_FILE"

    echo "更新 .SRCINFO 文件..."
    sed -i "s|pkgver = .*|pkgver = $java|" "$SRCINFO_FILE"
    sed -i "s|source_aarch64 = .*|source_aarch64 = $download_url_aarch64|" "$SRCINFO_FILE"
    sed -i "s|sha256sums_aarch64 = .*|sha256sums_aarch64 = $sha256_aarch64|" "$SRCINFO_FILE"
    sed -i "s|source_x86_64 = .*|source_x86_64 = $download_url_x86_64|" "$SRCINFO_FILE"
    sed -i "s|sha256sums_x86_64 = .*|sha256sums_x86_64 = $sha256_x86_64|" "$SRCINFO_FILE"

    echo "Zulu ${JAVA_VERSION} 处理完成!"
    echo ""
done

echo "========================================"
echo "所有版本处理完毕!"