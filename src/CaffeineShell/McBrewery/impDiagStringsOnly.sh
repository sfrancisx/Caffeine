#
# Import strings file for translation
#
# Caffeine 2013
# Brewery
#

cdir=`pwd`

shopt -s nullglob
for dirl in *.lproj; do
  basename=`basename "$dirl"`
  filename="${basename%.*}"
  echo "Importing $filename"

  if [ $filename != "en" ]; then

  cat "$dirl/YReportProblemWindowController.strings" |grep -v 549-mh-k5J | grep -v 205  > /tmp/xpto

  echo mv "$filename".lproj/YReportProblemWindowController.xib ~/tmp/Baks3/"$filename".diag
  mv "$filename".lproj/YReportProblemWindowController.xib ~/tmp/Baks3/"$filename".diag

  ibtool --strings-file /tmp/xpto  --write "$filename".lproj/YReportProblemWindowController.xib en.lproj/YReportProblemWindowController.xib

  #ibtool --strings-file "$dirl/YReportProblemWindowController.strings" --write "$filename".lproj/YReportProblemWindowController.xib en.lproj/YReportProblemWindowController.xib

  fi

done

#eof


