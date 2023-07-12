+++
title = "Making zola work for me"
date = 2023-07-12

[taxonomies]
tags = ["zola", "static site generator"]
+++

You might have seen that my site looks a bit different lately. I switched to a simpler Zola based setup. I set up a simple build pipeline,to automate the deployment of new posts. I also needed a way to make it faster for me to add a new post. I created a Bash script to make it easier for me.

<!-- more -->

The script is nothing special, but it automatically fills in `title`, `date`, as well as adds the `taxonomies` and `more` tag.

```
#!/bin/bash

# Get the post name from the command line argument
post_name="$1"

# Format the post name to generate the title
title=$(sed 's/-/ /g' <<< "$post_name" | awk '{print toupper(substr($0, 1, 1)) substr($0, 2)}')

# Set the file path
file_path="/home/fyksen/Projects/fyksen.me/content/${post_name}.md"

# Get the current date
current_date=$(date +"%Y-%m-%d")

# Create the file with the desired content
echo "+++" > "$file_path"
echo "title = \"${title}\"" >> "$file_path"
echo "date = ${current_date}" >> "$file_path"
echo "" >> "$file_path"
echo "[taxonomies]" >> "$file_path"
echo "tags = [\"tag1\", \"tag2\"]" >> "$file_path"
echo "+++" >> "$file_path"
echo "" >> "$file_path"
echo "Text" >> "$file_path"
echo "" >> "$file_path"
echo "<!-- more -->" >> "$file_path"
echo "" >> "$file_path"
echo "Text" >> "$file_path"


echo "New post created at: ${file_path}"

# <application name> ${file_path}
```

## Value add

* If you want to make it easier to link to photos, you could symlink your `static` direcory to the root, so previews work in your favorite markdown editor.

```
sudo ln -s <project path>/static/img /img
sudo chown $USER /img
```

* If you want to automatically open your markdown editor, you can remove the # on the last line and add your favorite editor in application name.


> This is mostly a note to myself about how this shit works..heh..

