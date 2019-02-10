# Magisk多合一模块安装脚本
# Special thanks to 
#   包包包先生 @ coolapk

# 配置
DEBUG_FLAG=true
AUTOMOUNT=true
POSTFSDATA=true
LATESTARTSERVICE=true

var_device="`grep_prop ro.product.device`"
var_version="`grep_prop ro.build.version.release`"

# 在这里设置你想要在模块安装过程中显示的信息
ui_print "*******************************"
ui_print "   Magisk多合一模块示例   "
ui_print "*******************************"
ui_print "  你的设备:$var_device"
ui_print "  系统版本:$var_version"

# $1:prop_text
add_sysprop()
{
  echo "$1" >> $MODPATH/system.prop
}

# $1:path/to/file
add_sysprop_file()
{
  cat "$1" >> $MODPATH/system.prop
}

# $1:path/to/file
add_service_sh()
{
  cp "$1" $MODPATH/service_sh/
}

# $1:path/to/file
add_postfsdata_sh()
{
  cp "$1" $MODPATH/postfsdata_sh/
}

# $1:ID of mod
check_mod_install()
{
  if [ "`echo $MODS_SELECTED_YES | grep \($1\)`" != "" ]; then
      echo -n "yes"
      return 0
  elif [ "`echo $MODS_SELECTED_NO | grep \($1\)`" != "" ]; then
      echo -n "no"
      return 0
  fi
  echo -n "unknown"
}

# 准备进行音量键安装
# Keycheck binary by someone755 @Github, idea for code below by Zappo @xda-developers
KEYCHECK=$INSTALLER/common/keycheck
chmod 755 $KEYCHECK

keytest() {
  ui_print "- 音量键测试 -"
  ui_print "   请按下 [音量+] 键："
  ui_print "   无反应或传统模式无法正确安装时，请触摸一下屏幕后继续"
  (/system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events) || return 1
  return 0
}

chooseport() {
  #note from chainfire @xda-developers: getevent behaves weird when piped, and busybox grep likes that even less than toolbox/toybox grep
  while (true); do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events
    if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUME >/dev/null`); then
      break
    fi
  done
  if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUMEUP >/dev/null`); then
    return 0
  else
    return 1
  fi
}

chooseportold() {
  # Calling it first time detects previous input. Calling it second time will do what we want
  $KEYCHECK
  $KEYCHECK
  SEL=$?
  $DEBUG_FLAG && ui_print "chooseportold: $1,$SEL"
  if [ "$1" == "UP" ]; then
    UP=$SEL
  elif [ "$1" == "DOWN" ]; then
    DOWN=$SEL
  elif [ $SEL -eq $UP ]; then
    return 0
  elif [ $SEL -eq $DOWN ]; then
    return 1
  else
    abort "   未检测到音量键!"
  fi
}

# 测试音量键
if keytest; then
	VOLKEY_FUNC=chooseport
  $DEBUG_FLAG && ui_print "func: $VOLKEY_FUNC"
	ui_print "*******************************"
else
	VOLKEY_FUNC=chooseportold
  $DEBUG_FLAG && ui_print "func: $VOLKEY_FUNC"
	ui_print "*******************************"
	ui_print "- 检测到遗留设备！使用旧的 keycheck 方案 -"
	ui_print "- 进行音量键录入 -"
	ui_print "   录入：请按下 [音量+] 键："
	$VOLKEY_FUNC "UP"
	ui_print "   已录入 [音量+] 键。"
	ui_print "   录入：请按下 [音量-] 键："
	$VOLKEY_FUNC "DOWN"
	ui_print "   已录入 [音量-] 键。"
ui_print "*******************************"
fi

# 替换文件夹列表
REPLACE=""

# 已安装模块
MODS_SELECTED_YES=""
MODS_SELECTED_NO=""

# 加载可用模块
cd $INSTALLER/common/mods
for MOD in $(ls)
do
  if [ -f $MOD/mod_info.sh ]; then
    source $MOD/mod_info.sh
    $DEBUG_FLAG && ui_print "load_mods: require_device:$require_device"
    $DEBUG_FLAG && ui_print "load_mods: require_version:$require_version"
    ui_print "  [$mod_name]安装"
    MODFILEDIR="$INSTALLER/common/mods/$MOD/files"
    if [ "`echo $var_device | egrep $require_device`" = "" ]; then
        ui_print "   [$mod_name]不支持您的设备。"
    elif [ "`echo $var_version | egrep $require_version`" = "" ]; then
        ui_print "   [$mod_name]不支持您的系统版本。"
    else
        ui_print "  - 请按音量键选择$mod_install_info -"
        ui_print "   [音量+]：$mod_yes_text"
        ui_print "   [音量-]：$mod_no_text"
        if $VOLKEY_FUNC; then
            ui_print "   已选择$mod_yes_text。"
            MODS_SELECTED_YES="$MODS_SELECTED_YES ($MOD)"
            mod_install_yes
            echo -n "[$mod_yes_text]; " >> $INSTALLER/module.prop
        else
            ui_print "   已选择$mod_no_text。"
            MODS_SELECTED_NO="$MODS_SELECTED_NO ($MOD)"
            mod_install_no
            echo -n "[$mod_no_text]; " >> $INSTALLER/module.prop
        fi
    fi
  fi
done

echo "" >> $INSTALLER/module.prop

