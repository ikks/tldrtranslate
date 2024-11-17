# tldrtranshelper

This is a helper to translate tldr pages, it's aimed to spanish but can
be modified to make use of other languages.

For now requires an argostranslate API to make automatic translation that
needs to be supervised and edited by a human.

## Requirements

* You need zig 0.13.0 to run this helper
* API argos-translate instance running
* For spanish data to tweak the verb inflection

Feel free to clone and modify to suit your needs.

## Running

Have an Argos API locally, to run it:

```
fastapi dev main
```

## Choosing a language

Set your env var TLDR_LANG="xx" replacing xx for your language. Please
note there is a list of [supported languages by Argos Translate](https://github.com/argosopentech/argos-translate).

## Building a new language
