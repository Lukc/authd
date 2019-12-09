
package=authd
version=0.2.0

targets=(authd)
type[authd]=crystal
sources[authd]=src/main.cr
depends[authd]="$(ls src/*.cr | grep -v '/main.cr$' | tr '\n' ' ')"

targets+=(client/main.js)
type[client/main.js]=livescript
sources[client/main.js]=client/index.ls
depends[client/main.js]="$(ls client/*.ls | grep -v '/index.ls$' | tr '\n' ' ')"

targets+=(client/style.css)
type[client/style.css]=sass
sources[client/style.css]=client/style.sass

