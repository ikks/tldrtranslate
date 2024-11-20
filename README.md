# tldrtranshelper

This is a helper to translate tldr pages, it's aimed to spanish but can
be modified to make use of other languages.

For now requires an argostranslate API to make automatic translation that
needs to be supervised and edited by a human.

## Requirements

* You need [zig 0.13.0](https://ziglang.org/download/) to run this helper
* [argos-API](https://github.com/Jaro-c/Argos-API) translate instance running, in port 8000
* For spanish data to tweak the verb inflection

Feel free to clone and modify to suit your needs.

## Running

Have an [Argos-API](https://github.com/Jaro-c/Argos-API) locally, to run it, with your
language pairs:

```
fastapi dev main
```

## Choosing a language

Set your env var TLDR_LANG="xx" replacing xx for your language. Please
note there is a list of [supported languages by Argos Translate](https://github.com/argosopentech/argos-translate).

## Building a new language

If your language is in the list of supported languages by Argos-translate, just download the required package to your running environment.  For example for portuguese `argospm install translate-en_pt`, is the same for PT or BR.

If your language is not supported by Argos-translate, you can [open an issue in Argos-translate](https://github.com/argosopentech/argos-translate/discussions/91).

If you need to postprocess a translation, you can follow what was done for spanish.


## Acknowledgments

* [Argos-translate](https://github.com/argosopentech/argos-translate) with tons of work.
* Compjugador

# Resources

* [Verbs conversion](https://igor.tamarapatino.org/tldrtranslate/resources/es/data.mdb.gz)
