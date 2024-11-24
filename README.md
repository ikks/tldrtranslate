# tldrtranshelper

This is a helper to translate tldr pages, the list of supported languages is:

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
* uk  
* zh  
* zh_TW

The workflow is:
 * `tldrtranslate` translates from English to the language you desire.
 * With your team, you can fix the output and make a pull request.

## Download and usage

 * Download for your platform.
 * Download argostranslate API and argostranslate and make the API run.
 * Download a helper for spanish (not needed for other languages).

If you are having problems getting the API and argos-translate to run, please ask 
in https://app.element.io/#/room/#tldr-pages:matrix.org , maybe there is someone
that can put a server for your use.

### Linux installation

If you are translating to spanish, please do the following:
```
mkdir -p /tmp/tldr_translation.db && cd $_ && wget https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz && gunzip data.mdb.gz
```

It downloads the database that helps to transform some verbs from infinitive and imperative to adhere to the style we are already using.

## Running

Suppose you aim to translate `pages/common/argos-translate.md` to `it` , you will run:

``` 
tldrtranslate -l it pages/common/argos-translate.md
```

`tldrtranslate` will output the translation to `pages.it/common/argos-translate.md`, overwriting the file if it existed

You can use relative or absolute paths, as soon as you include the hierarchy from `pages` directory.

You can set the following ENV_VARS to change the default configurations:
*  TLDR_LANG: defaults to `es` (spanish) 
*  TLDR_ARGOS_API_URLBASE: defaults to `localhost`
*  TLDR_ARGOS_API_PORT: Defaults to `8000`
*  TLDR_ES_DB_PATH: Defaults to `/tmp/tldr_translation.db`

each one of them is superseeded by the option of the command line

* -l es
* -u localhost
* -p 8000
* -d /tmp/tldr_translation.db

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

If you need to postprocess a translation, you can follow what was done for spanish.


## Acknowledgments

* [Argos-translate](https://github.com/argosopentech/argos-translate) with tons of work.
* Compjugador

# Resources

* [Verbs conversion](https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz)
