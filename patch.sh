set -e
binary_name=xochitl
# quick hack for low disk space
# TODO check free space
journalctl --vacuum-time=1m

trap onexit INT

function onexit(){
    cleanup
    auto_install

    exit 0
}
function cleanup(){
    echo "cleaning up"
    rm /tmp/*crash* 2> /dev/null || true
    rm -fr .cache/remarkable/xochitl/qmlcache/*
}

function rollback(){
    systemctl stop xochitl
    cleanup
    cp $backup_file /usr/bin/xochitl
    systemctl start xochitl
    exit 0
}

function auto_install(){
    echo -n "If everything worked, do you want to make it permanent [N/y]?"
    read yn
    case $yn in 
        [Yy]* ) 
            echo "Making it permanent"
            mv $binary_name.patched /usr/bin/$binary_name
            echo "Starting the UI"
            systemctl start xochitl
            return 0
            ;;
        * )
            rm $binary_name.patched
            echo "Staring the original"
            systemctl start xochitl
            ;;
    esac
    return 1
}


case $(</etc/version) in
    "20191204111121" )
        patch_name=${1:-patch_224}
        version="2020"
        echo "Version 2.0.2.0"
        ;;
    "20191123105338" )
        patch_name=${1:-patch_204}
        version="2011"
        echo "Version 2.0.1.1"
        ;;
        
    "20190904134033" )
        patch_name=${1:-patch_07}
        version="1811"
        echo "Version 1.8.1.1"
        ;;
    * )
        echo "Unsupported version"
        exit 1
        ;;
esac

if [ -z "$SKIP_DOWNLOAD" ]; then
    wget "https://github.com/ddvk/remarkable-hacks/raw/master/patches/$version/$patch_name" -O $patch_name || exit 1
fi

backup_file="${binary_name}.${version}"

if [ $patch_name == "rollback" ]; then
    rollback
    exit 0
fi

#make sure we keep the original
if [ ! -f $backup_file ]; then
    cp /usr/bin/$binary_name $backup_file
fi
cp $backup_file $binary_name

bspatch $binary_name $binary_name.patched $patch_name
chmod +x xochitl.patched

systemctl stop xochitl
#just to be sure, it goes into and endless reboot due to qml mismatch
systemctl stop remarkable-fail
 
cleanup
echo "Trying to start the patched version"
echo "You can play around, press CTRL-C when done"
./xochitl.patched > /dev/null 2>&1 || echo "It crashed?"
cleanup
