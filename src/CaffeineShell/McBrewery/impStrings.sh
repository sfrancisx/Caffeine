echo "Updating Single language codes BEFORE  import"
./updSingleCodes.sh
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

  
  # removing some incorrect translation keys
  #cat "$dirl/MainMenu.strings" |grep -v 5m5-4i-iqt  | grep -v EzF-SC-Chi > /tmp/xpto
  #ibtool --strings-file /tmp/xpto  --write "$filename".lproj/MainMenu.xib en.lproj/MainMenu.xib
  #cat "$dirl/YReportProblemWindowController.strings" |grep -v 549-mh-k5J | grep -v 205  > /tmp/xpto
  #ibtool --strings-file /tmp/xpto  --write "$filename".lproj/YReportProblemWindowController.xib en.lproj/YReportProblemWindowController.xib
  
  ibtool --strings-file "$dirl/MainMenu.strings" --write "$filename".lproj/MainMenu.xib en.lproj/MainMenu.xib

  ibtool --strings-file "$dirl/YReportProblemWindowController.strings" --write "$filename".lproj/YReportProblemWindowController.xib en.lproj/YReportProblemWindowController.xib


done

#eof


