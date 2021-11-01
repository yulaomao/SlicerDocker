#!/bin/bash

set -e
set +x

script_dir=$(cd $(dirname $0) || exit 1; pwd)
PROG=$(basename $0)

err() { echo -e >&2 ERROR: $@\\n; }
die() { err $@; exit 1; }

if [ "$#" -ne 1 ]; then
  die "Usage: $PROG /path/to/Slicer-X.Y.Z-linux-amd64/Slicer"
fi

slicer_executable=$1

################################################################################
# Set up headless environment
source $script_dir/start-xorg.sh
echo "XORG_PID [$XORG_PID]"

################################################################################
# Set up Slicer extensions

echo "Set default application settings"
# - use CPU volume rendering (it is better optimized for software rendering)
$slicer_executable -c '
slicer.app.settings().setValue("VolumeRendering/RenderingMethod","vtkMRMLCPURayCastVolumeRenderingDisplayNode")
slicer.app.settings().setValue("Markups/GlyphScale", 3)
slicer.app.settings().setValue("Markups/UseGlyphScale", True)
'





################################################################################
# Shutdown headless environment
kill -9 $XORG_PID
rm /tmp/.X10-lock