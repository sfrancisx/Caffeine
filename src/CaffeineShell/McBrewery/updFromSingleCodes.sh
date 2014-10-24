#!/bin/sh

shopt -s nullglob
for dirl in ??.lproj; do
  basename=`basename "$dirl"`

  filename="${basename%.*}"

  if [ $filename !=  "zh" ]; then

     for cdir in ${filename}-* ; do

      echo cp "${filename}.lproj/YReportProblemWindowController.strings" "${cdir}/"
      cp "${filename}.lproj/YReportProblemWindowController.strings" "${cdir}/"

     done

  fi

done

#eof
