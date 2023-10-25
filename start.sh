#!/bin/bash
##################################################
## variables
##################################################

CONFIG_FILE="config.json"
JAR_FILE="server.jar"
URL="https://api.papermc.io/v2/projects"
BUILD_DIR="plugins/build"

##################################################
## functions
##################################################
# showTitle
function showTitle() {
    echo "############################################"
    echo "## $1"
    echo "############################################"
}

echo_wrp(){
    echo "[mc-server] $1"
}

# 必要なパッケージを確認
function checkRequire() {
    # java
    if ! type java > /dev/null 2>&1; then
        echo "java not found"
        exit 1
    fi

    # jq
    if ! type jq > /dev/null 2>&1; then
        echo "jq not found"
        exit 1
    fi

    # curl
    if ! type curl > /dev/null 2>&1; then
        echo "curl not found"
        exit 1
    fi

    # config file
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "config file not found"
        exit 1
    fi
}

# サーバーの最新ビルドを取得
getServer(){
    showTitle "get server jar..."
    # サーバーの種類を取得
    local SERVER_TYPE=$(jq -r '.server_type' $CONFIG_FILE)
    # サーバーのバージョンを取得
    local SERVER_VERSION=$(jq -r '.server_version' $CONFIG_FILE)
    # サーバーの最新ビルドを取得
    echo_wrp "URL: $URL/$SERVER_TYPE/versions/$SERVER_VERSION"
    local LATEST_BUILD=$(curl -s $URL/$SERVER_TYPE/versions/$SERVER_VERSION | jq -r '.builds[-1]')
    echo_wrp "latest build: $LATEST_BUILD"

    # サーバーの最新ビルドをダウンロード
    echo_wrp "download server"
    local JAR_URL="$URL/$SERVER_TYPE/versions/$SERVER_VERSION/builds/$LATEST_BUILD/downloads/$SERVER_TYPE-$SERVER_VERSION-$LATEST_BUILD.jar"
    echo_wrp "URL: $JAR_URL"
    curl -s -o $JAR_FILE $JAR_URL

    echo_wrp "download complete !"
}

# プラグインをビルド
buildPlugin(){
    showTitle "build plugin..."
    # plugin list
    local PLUGIN_LIST=$(jq -r '.plugins' $CONFIG_FILE)
    echo_wrp "plugin list: $PLUGIN_LIST"
    local length=$(echo $PLUGIN_LIST | jq length)
    echo_wrp "plugin length: $length"

    local current_dir=$(pwd)
    # Loop through the PLUGIN_LIST array
    for (( i=0; i<$length; i++ )); do
        local plugin_name=$(echo $PLUGIN_LIST | jq -r ".[$i].name")
        local plugin_url=$(echo $PLUGIN_LIST | jq -r ".[$i].url")
        echo_wrp "plugin name: $plugin_name"
        echo_wrp "plugin url: $plugin_url"
        local plugin_dir="$BUILD_DIR/$plugin_name"
        git clone $plugin_url $plugin_dir/
        cd $plugin_dir
        ./gradlew build
        echo_wrp "build complete !"
        ls

        cd $current_dir
    done
}

##################################################
## main
##################################################
main(){
    showTitle "start server"
    # 必要なパッケージを確認
    checkRequire

    # config fileから設定を読み込む
    local SERVER_TYPE=$(jq -r '.server_type' $CONFIG_FILE)
    local SERVER_VERSION=$(jq -r '.server_version' $CONFIG_FILE)
    local SERVER_MEM=$(jq -r '.server_mem' $CONFIG_FILE)


    echo "server name: $SERVER_NAME"
    echo "server version: $SERVER_VERSION"
    echo "server mem: $SERVER_MEM"

    # サーバーをダウンロード
    getServer &
    local SERVER_DOWNLOAD_PID=$!
    echo_wrp "download server pid: $SERVER_DOWNLOAD_PID"

    # プラグインをビルド
    mkdir -p $BUILD_DIR
    buildPlugin &
    local PLUGIN_BUILD_PID=$!
    echo_wrp "build plugin pid: $PLUGIN_BUILD_PID"

    # サーバーのダウンロードが完了するまで待機
    wait $SERVER_DOWNLOAD_PID
    echo_wrp "download server complete !"

    # プラグインのビルドが完了するまで待機
    wait $PLUGIN_BUILD_PID
    echo_wrp "build plugin complete !"
}

main