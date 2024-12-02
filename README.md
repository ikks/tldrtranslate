# tldrtranshelper

https://github.com/user-attachments/assets/b81b3895-aa8d-443b-84d5-057d9ecc4041

This is a helper to translate [tldr pages](https://tldr.sh/), the list of supported languages is:

* ar
* bn
* ca
* cs
* da
* de
* es
* fa
* fi
* fr
* hi
* id
* it
* ja
* ko
* nl
* pl
* pt_BR
* pt_PT
* ro
* ru
* sv
* th
* tr
* uk
* zh
* zh_TW

The workflow is:
 * `tldrtranslate` translates from English to the language you desire.
 * With your team, you can fix the output and make a pull request.

## Download and usage

 * Download for your platform from the [releases page](https://github.com/ikks/tldrtranslate/releases), take the latest one.
 * Download argostranslate API and argostranslate and make the API run.

If you are having problems getting the API and argos-translate to run, please ask 
in https://app.element.io/#/room/#tldr-pages:matrix.org , maybe there is someone
that can put a server for your use.

## Running

Suppose you aim to translate `pages/common/argos-translate.md` to `it` , you will run:

``` 
tldrtranslate -l it pages/common/argos-translate.md
```

`tldrtranslate` will output the translation to `pages.it/common/argos-translate.md`, overwriting the file if it existed

You can use relative or absolute paths, as soon as you include the hierarchy from `pages` directory.

`tldrtranslate` takes into account the following env vars:

* LANG: if set and with a supported language, is used unless TLDR_LANG is set or -L option is passed
* NO_COLOR: if set, the output with -y option will not show colors

You can set the following ENV_VARS to change the default configurations:

*  TLDR_LANG: defaults to `es` (spanish) 
*  TLDR_ARGOS_API_URLBASE: defaults to `localhost`
*  TLDR_ARGOS_API_PORT: Defaults to `8000`
*  TLDR_ES_DB_PATH: Your spanish db to present singular verb tweak, has no default

each one of them is superseeded by the option of the command line

* -L es
* -H localhost
* -P 8000
* -d path/to/tldr_translation.db

## Building from source

* You need [zig 0.13.0](https://ziglang.org/download/) to compile tldrtranslate
* Clone this repository

And issue

```
zig build
```

Under `zig-out/bin/` should be present `tldrtranslate` for your use.

* [argos-API](https://github.com/Jaro-c/Argos-API) translate instance running, in port 8000
* For spanish data to tweak the verb inflection

Feel free to clone and modify to suit your needs.

## Running an Argos API instance

You will need to have python, argos-translate and api argos-translate or Docker and some Gigas of space for the models and the needed infrastructure.

Have an [Argos-API](https://github.com/Jaro-c/Argos-API) locally. To run it, with your
language pairs you can issue on your virtualenv:

```
fastapi dev main
```

## Building a new language

If your language is in the list of supported languages by Argos-translate, just download the required package to your running environment.  For example for portuguese `argospm install translate-en_pt`, is the same for PT or BR.

If your language is not supported by Argos-translate, you can [open an issue in Argos-translate](https://github.com/argosopentech/argos-translate/discussions/91).

## Adding common replacements for your language

If you want to have consistent translations, there are some words that can be replaced befor the translation process, please look [here](docs/language_replacements.md).

## Acknowledgments

* [Argos-translate](https://github.com/argosopentech/argos-translate) with tons of work.
* Compjugador

# Resources

* [Spanish verbs conversion](https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz)

