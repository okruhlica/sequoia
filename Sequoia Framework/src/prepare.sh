#!/bin/sh

foo="BEGIN TRANSACTION;\n"

# Append init.sql file from root
foo="$foo\n\n--- File: /init.sql ----\n\n"
	while IFS= read line ; do
		foo="$foo$line\n"
	done <"init.sql"
	
	
# Append init.sql files from subfolders
IFS=$'\n'
for file in $(find ./*/ -type f -name "init.sql") ; do
	foo="$foo\n\n--- File: $file ----\n\n"
	while IFS= read line ; do
		foo="$foo$line\n"
	done <"$file"
done

# Append functions.sql file from root
foo="$foo\n\n--- File: /functions.sql ----\n\n"
	while IFS= read line ; do
		foo="$foo$line\n"
	done <"functions.sql"
	

# Append functions.sql files
for file in $(find ./*/ -type f -name "functions.sql") ; do
	foo="\n\n$foo--- Function file: $file ----\n"
	while IFS= read line ; do
		foo="$foo$line\n"
	done <"$file"
done

foo="$foo\nEND TRANSACTION;\n"
mkdir -p "../dist/"
cd "../dist/"
touch "sequoia.sql"
echo "$foo" > "sequoia.sql"
echo "Done."
