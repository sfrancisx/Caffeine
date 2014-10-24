#
# Generate strings file for translation
#
# Caffeine 2013
# Brewery
#

cdir=`pwd`
#strdir=`pwd`/Strings

shopt -s nullglob
for dirl in *.lproj; do
  basename=`basename "$dirl"`
  filename="${basename%.*}"
  echo "Exporting $filename"

  echo ibtool --generate-strings-file  "$basename"/MainMenu.strings "$basename"/MainMenu.xib
  ibtool --generate-strings-file  "$basename"/MainMenu.strings "$basename"/MainMenu.xib

  echo ibtool --generate-strings-file  "$basename"/YReportProblemWindowController.strings "$basename"/YReportProblemWindowController.xib
  ibtool --generate-strings-file  "$basename"/YReportProblemWindowController.strings "$basename"/YReportProblemWindowController.xib


done

#eof

