#!/bin/bash
set -e

#
# Automated script to generate a standalone install file.
#

THIS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

INSTALL_FILENAME=install-ibb.sh

cat << EOF > $INSTALL_FILENAME
#!/bin/bash
set -e
set -o noglob
set -o pipefail

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This file is dynamically generated. Do not overwrite anything
# in here unless you know what you are doing!
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
EOF

# Wrapping 'EOF' in quotes negates variable expansion
cat $THIS_SCRIPT_DIR/header.sh >> $INSTALL_FILENAME

# Cat all the lib/*.sh files into `install-ibb.sh`
for f in $THIS_SCRIPT_DIR/lib/install/*.sh ; do
  cat $f >> $INSTALL_FILENAME
  echo "" >> $INSTALL_FILENAME
done


# Wrapping 'EOF' in quotes negates variable expansion
cat $THIS_SCRIPT_DIR/footer.sh >> $INSTALL_FILENAME

echo "[*] Successfully created $INSTALL_FILENAME file."
