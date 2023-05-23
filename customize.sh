# BluetoothLibraryPatcher
# by 3arthur6

check() {
if ! $KSU ; then
  ui_print "- Only for KernelSU，you can use magisk with https://github.com/3arthur6/BluetoothLibraryPatcher."
  abort
fi
 ui_print "- KernelSU installation"
 sys=/system

  if ! $samsung ; then
    ui_print "- Only for Samsung devices!"
    abort
  elif ! `grep -qw ro.build.type=user $sys/build.prop` ; then
    ui_print "- Only for Samsung stock based roms!"
    ui_print "- Not relevant for aosp roms!"
    abort
  elif [[ $API -lt 24 ]] ; then
    ui_print "- Only for Android 7.0 (Nougat) and above"
    abort
  fi
}

search() {
  ui_print "- Searching for relevant hex byte sequence"
  unzip -q $ZIPFILE hexpatch.sh -d $TMPDIR
  chmod 755 $TMPDIR/hexpatch.sh
  # Executed through bash for array handling
  unzip -p $ZIPFILE bash.tar.xz|tar x -J -C $TMPDIR bash
  chmod 755 $TMPDIR/bash
  if [[ $API -le 32 ]] ; then
    lib=`find $sys/lib*|grep -E "\/(libbluetooth|bluetooth\.default)\.so$"|tail -n 1`
  else
    bits=`$IS64BIT && echo '64'`
    unzip -p $ZIPFILE 7z.tar.xz|tar x -J -C $TMPDIR 7z
    chmod 755 $TMPDIR/7z
    unzip -q $sys/apex/com.android.btservices.apex apex_payload.img -d $TMPDIR
    $TMPDIR/7z x -y -bso0 $TMPDIR/apex_payload.img lib$bits/libbluetooth_jni.so -o$TMPDIR/system
    lib=$TMPDIR/system/lib$bits/libbluetooth_jni.so
  fi
  export TMPDIR API IS64BIT lib
  $TMPDIR/bash $TMPDIR/hexpatch.sh
}

patchlib() {
  ui_print "- Applying patch"
  pre=`grep pre_hex $TMPDIR/tmp|cut -d '=' -f2`
  post=`grep post_hex $TMPDIR/tmp|cut -d '=' -f2`
  if [[ $pre == already ]] ; then
    ui_print "- Library already (system-ly) patched!"
    abort
  elif [[ -f $lib ]] && [[ ! -z $pre ]] ; then
    mod_path=$MODPATH/`echo $lib|grep -o system.*`
    mkdir -p `dirname $mod_path`
    xxd -p -c `stat -c %s $lib` $lib|sed "s/$pre/$post/"|xxd -pr -c `stat -c %s $lib` > $mod_path
  fi
  if [[ -f $lib ]] && `xxd -p $mod_path|tr -d ' \n'|grep -qm1 $post` ; then
    ui_print "- Successfully patched!"
  else
    ui_print "- Patch failed!"
    echo -e "BOOTMODE=$BOOTMODE\nAPI=$API\nIS64BIT=$IS64BIT\nlib=$lib" >> $TMPDIR/tmp
    cp -f $lib $TMPDIR
    tar c -f /sdcard/BluetoothLibPatcher-files.tar -C $TMPDIR `ls $TMPDIR|sed -E '/bash|hexpatch\.sh|7z/d'`
    ui_print " "
    ui_print "- Opening support webpage in 10 seconds"
    (sleep 10 && am start -a android.intent.action.VIEW -d https://github.com/3arthur6/BluetoothLibraryPatcher/blob/master/SUPPORT.md >/dev/null) &
    abort
  fi
}

patchmanifest() {
    ui_print "- Applying gear watch fix"
    mkdir -p /system/vendor/vintf/manifest
    for i in `grep -lr 'security.wsm' /vendor/etc/vintf`
    do
      if [[ ! -z $i ]] ; then
        rm -f $MODPATH/system$i
        cp -af $i $MODPATH/system$i
        sed -i $((`awk '/security.wsm/ {print FNR}' $i`-1)),/<\/hal>/d $MODPATH/system$i
      fi
    done
}

check
search
patchlib
patchmanifest
