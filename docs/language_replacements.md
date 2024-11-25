# Adding replacements for your commands

It's possible to replace portions of the command executions, and
the information that is common in many files, the summary.

For this, the most important part is to provide the translations.

The process is:

1. Copy the template file for your language and place it into `src`.
2. Modify the contents of the file to adjust the replacements.
3. Register the replacements and associate them to the specific language.
4. Build the project
5. Test the results

For the rest of the document we will take language 'dr' and the page
`pages/common/tar.md` as example.

## Copy the template to your language

```
cp templates/l_xx.zig src/l_dr.zig
```

When looking at the dirs and files, the new language should appear in the
same directory as `l_es.zig`

```
├── LICENSE
├── README.md
├── src
│   ├── extern.zig
│   ├── lang_dr.zig
│   ├── lang_es.zig
.
.
.
│   ├── main.zig
│   ├── tldr-base.zig
│   └── tldr.zig
├── templates
│   └── l_xx.zig
```

## Modify the contents of the new file

Edit `src/l_dr.zig` and replace the empty strings with the translation.

You will notice that the file has around 80 strings to be translated, those
are the most common found, each of them appears at least 20 times in the tldr pages.

Here you see that the string `path/to/file_or_directory` is replaced by `your/translation/here`.

```
    Replacement{ .original = "path/to/file_or_directory", .replacement = "your/translation/here" },
```

## Link your work with the project

If you want to skip this part and go directly to make a pull request, do not hesitate. We can help
merging your work.  But still is more fun to be able to test your work.

It's a matter of adding two lines to `src/main.zig`.

Open `src/main.zig` and find `l_es`, you will find two lines in the file, both close at the
beginning, add yours below `// Importing Language replacements`.

```
const l_dr = lang_dr.l_dr;
```

And the other just below `// Add your language replacemens here, better alphabetically`

```
    try replacements.put("dr", l_dr);
```

And given that you have your replacemens in place, we need to remove the default behaviour
from `src/tldr-base.zig`.  There you will find the previous definition looking for `supported_default_languages`,
there we remove the line that contains "dr", and we will be set.

## Build the project

To build the project and test we need [zig](https://ziglang.org/download/) version 0.13.0, once it's installed, issue:

```terminal
time zig build run -- -y  -l dr pages/common/argocd-app.md 
```

that will show the translated content to `dr`.

## Test the results

Subsequently you can run with different files to see if your replacements are
working as expected.

If it's your first interaction with Zig and you've seen the replacements for your language, congratulations!

## Make a Pull Request

Make your pull request and allow it to be modified, just in case anything needs to be tweaked.
