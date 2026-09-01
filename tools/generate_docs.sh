#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
staging_directory="$repository_root/docs/gnatdoc/staging"
output_directory="$repository_root/docs/gnatdoc/html"
object_directory="$repository_root/docs/gnatdoc/obj"
documentation_project="$repository_root/docs/gnatdoc/gnatdoc.gpr"

if [ -x "$repository_root/.alire/gnatdoc/bin/gnatdoc" ]; then
   gnatdoc_command="$repository_root/.alire/gnatdoc/bin/gnatdoc"
else
   gnatdoc_command=gnatdoc
fi

mkdir -p "$staging_directory" "$output_directory" "$object_directory"

for source_name in \
   flyology_crc.ads \
   flyology_crc-width_16.ads \
   flyology_crc-width_32.ads \
   flyology_crc-width_64.ads
do
   awk '
      /^package [A-Za-z0-9_.]+ is$/ {
         package_name = $2
      }
      /^private$/ {
         print "end " package_name ";"
         exit
      }
      {
         print
      }
   ' "$repository_root/src/$source_name" > "$staging_directory/$source_name"
done

if ! gnatdoc_output=$(
   alr exec -- "$gnatdoc_command" \
      --backend html \
      --warnings \
      --style leading \
      --generate public \
      -O "$output_directory" \
      -P "$documentation_project" 2>&1
); then
   printf '%s\n' "$gnatdoc_output"
   exit 1
fi

printf '%s\n' "$gnatdoc_output"
if printf '%s\n' "$gnatdoc_output" | grep -Eq '(^|:) warning:'; then
   printf '%s\n' "GNATdoc reported incomplete public API documentation." >&2
   exit 1
fi
