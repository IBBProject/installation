#!/bin/bash
set -e

#
# Automated script to generate a standalone install file.
#

THIS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

INSTALL_FILENAME=update-ibb.sh

cat $THIS_SCRIPT_DIR/header.sh > $INSTALL_FILENAME
cat $THIS_SCRIPT_DIR/lib/install/log.sh >> $INSTALL_FILENAME
cat $THIS_SCRIPT_DIR/lib/install/check_root.sh >> $INSTALL_FILENAME
cat $THIS_SCRIPT_DIR/lib/install/check_required_binaries.sh >> $INSTALL_FILENAME
cat $THIS_SCRIPT_DIR/lib/install/create_ibb_install_dir.sh >> $INSTALL_FILENAME

# Cat all the lib/*.sh files into `install-ibb.sh`
for f in $THIS_SCRIPT_DIR/lib/update/*.sh ; do
  cat $f >> $INSTALL_FILENAME
  echo "" >> $INSTALL_FILENAME
done

cat << EOF >> $INSTALL_FILENAME

check_root
create_ibb_install_dir
check_required_binaries
update_ktunnel

EOF

echo "[*] Successfully created $INSTALL_FILENAME file."
